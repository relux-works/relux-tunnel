package udp

import (
	"context"
	"net"
	"net/netip"
	"unicode"

	"github.com/relux-works/relux-tunnel/relay/internal/protocol"
)

type systemResolver struct{}

func (systemResolver) LookupNetIP(ctx context.Context, network, host string) ([]netip.Addr, error) {
	return net.DefaultResolver.LookupNetIP(ctx, network, host)
}

func validateResolverName(name []byte) *IOFailure {
	if len(name) < int(protocol.MinDomainWireBytes) || len(name) > int(protocol.MaxDomainWireBytes) {
		return invalidDatagramFailure()
	}
	end := len(name)
	if name[end-1] == '.' {
		end--
		if end == 0 || name[end-1] == '.' {
			return invalidDatagramFailure()
		}
	}
	if parsed, err := netip.ParseAddr(string(name[:end])); err == nil && parsed.IsValid() {
		return invalidDatagramFailure()
	}
	labelStart := 0
	for index := 0; index <= end; index++ {
		if index != end && name[index] != '.' {
			value := name[index]
			if !asciiLetter(value) && !asciiDigit(value) && value != '-' {
				return invalidDatagramFailure()
			}
			continue
		}
		label := name[labelStart:index]
		if len(label) == 0 || len(label) > 63 || label[0] == '-' || label[len(label)-1] == '-' {
			return invalidDatagramFailure()
		}
		if hasASCIIPrefixFold(label, "xn--") && !validPunycode(label[4:]) {
			return invalidDatagramFailure()
		}
		labelStart = index + 1
	}
	return nil
}

func asciiLetter(value byte) bool {
	return value >= 'A' && value <= 'Z' || value >= 'a' && value <= 'z'
}

func asciiDigit(value byte) bool { return value >= '0' && value <= '9' }

func hasASCIIPrefixFold(value []byte, prefix string) bool {
	if len(value) < len(prefix) {
		return false
	}
	for index := range prefix {
		left := value[index]
		if left >= 'A' && left <= 'Z' {
			left += 'a' - 'A'
		}
		if left != prefix[index] {
			return false
		}
	}
	return true
}

// validPunycode validates the RFC 3492 encoding after the xn-- prefix. It
// deliberately does not normalize or materialize Unicode output.
func validPunycode(input []byte) bool {
	if len(input) == 0 {
		return false
	}
	const (
		base        = uint64(36)
		tMin        = uint64(1)
		tMax        = uint64(26)
		skew        = uint64(38)
		damp        = uint64(700)
		initialBias = uint64(72)
		initialN    = uint64(128)
		maxRune     = uint64(0x10FFFF)
	)
	outputLength := uint64(0)
	position := 0
	lastDelimiter := -1
	for index, value := range input {
		if value == '-' {
			lastDelimiter = index
		}
	}
	if lastDelimiter >= 0 {
		if lastDelimiter == 0 {
			return false
		}
		for _, value := range input[:lastDelimiter] {
			if value >= 0x80 || (!asciiLetter(value) && !asciiDigit(value) && value != '-') {
				return false
			}
			outputLength++
		}
		position = lastDelimiter + 1
	}
	if position == len(input) {
		return false
	}

	n := initialN
	bias := initialBias
	delta := uint64(0)
	for position < len(input) {
		oldDelta := delta
		weight := uint64(1)
		for k := base; ; k += base {
			if position >= len(input) {
				return false
			}
			digit, ok := punycodeDigit(input[position])
			if !ok || digit > (^uint64(0)-delta)/weight {
				return false
			}
			position++
			delta += digit * weight
			threshold := tMin
			if k > bias+tMin {
				threshold = k - bias
			}
			if threshold > tMax {
				threshold = tMax
			}
			if digit < threshold {
				break
			}
			multiplier := base - threshold
			if weight > ^uint64(0)/multiplier {
				return false
			}
			weight *= multiplier
		}
		outputLength++
		bias = adaptPunycode(delta-oldDelta, outputLength, oldDelta == 0, damp, base, tMin, tMax, skew)
		if delta/outputLength > maxRune-n {
			return false
		}
		n += delta / outputLength
		if n > maxRune || n >= 0xD800 && n <= 0xDFFF {
			return false
		}
		decoded := rune(n)
		if !unicode.IsLetter(decoded) && !unicode.IsDigit(decoded) && !unicode.IsMark(decoded) {
			return false
		}
		delta %= outputLength
		delta++
	}
	return outputLength > 0
}

func punycodeDigit(value byte) (uint64, bool) {
	switch {
	case value >= 'a' && value <= 'z':
		return uint64(value - 'a'), true
	case value >= 'A' && value <= 'Z':
		return uint64(value - 'A'), true
	case value >= '0' && value <= '9':
		return uint64(value-'0') + 26, true
	default:
		return 0, false
	}
}

func adaptPunycode(delta, points uint64, first bool, damp, base, tMin, tMax, skew uint64) uint64 {
	if first {
		delta /= damp
	} else {
		delta /= 2
	}
	delta += delta / points
	threshold := (base - tMin) * tMax / 2
	k := uint64(0)
	for delta > threshold {
		delta /= base - tMin
		k += base
	}
	return k + (base-tMin+1)*delta/(delta+skew)
}
