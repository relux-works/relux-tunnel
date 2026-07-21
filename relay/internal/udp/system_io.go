package udp

import (
	"errors"
	"net/netip"
	"syscall"

	"github.com/relux-works/relux-tunnel/relay/internal/protocol"
)

var errUnsupportedSourceEndpoint = errors.New("unsupported source endpoint")

type systemSocketOperations struct{}

func (systemSocketOperations) SendTo(
	descriptor int,
	family AddressFamily,
	address netip.Addr,
	port uint16,
	payload []byte,
) error {
	if port == 0 || !address.IsValid() {
		return syscall.EINVAL
	}
	switch family {
	case AddressFamilyIPv4:
		if !address.Is4() {
			return syscall.EAFNOSUPPORT
		}
		sockaddr := &syscall.SockaddrInet4{Port: int(port), Addr: address.As4()}
		return syscall.Sendto(descriptor, payload, 0, sockaddr)
	case AddressFamilyIPv6:
		if !address.Is6() || address.Is4In6() || address.Zone() != "" {
			return syscall.EAFNOSUPPORT
		}
		sockaddr := &syscall.SockaddrInet6{Port: int(port), Addr: address.As16()}
		return syscall.Sendto(descriptor, payload, 0, sockaddr)
	default:
		return syscall.EAFNOSUPPORT
	}
}

func (systemSocketOperations) ReceiveFrom(
	descriptor int,
	family AddressFamily,
	buffer []byte,
) (int, protocol.DatagramEndpoint, bool, error) {
	read, _, flags, source, err := syscall.Recvmsg(descriptor, buffer, nil, 0)
	if err != nil {
		return 0, protocol.DatagramEndpoint{}, false, err
	}
	return receiveFromResult(read, family, flags, source)
}

func receiveFromResult(
	read int,
	family AddressFamily,
	flags int,
	source syscall.Sockaddr,
) (int, protocol.DatagramEndpoint, bool, error) {
	if flags&syscall.MSG_TRUNC != 0 {
		return read, protocol.DatagramEndpoint{}, true, nil
	}
	endpoint, err := endpointFromSockaddr(family, source)
	if err != nil {
		return read, protocol.DatagramEndpoint{}, false, err
	}
	return read, endpoint, false, nil
}

func endpointFromSockaddr(
	family AddressFamily,
	source syscall.Sockaddr,
) (protocol.DatagramEndpoint, error) {
	switch value := source.(type) {
	case *syscall.SockaddrInet4:
		if family != AddressFamilyIPv4 || value.Port <= 0 || value.Port > 65535 {
			return protocol.DatagramEndpoint{}, errUnsupportedSourceEndpoint
		}
		address := make([]byte, 4)
		copy(address, value.Addr[:])
		return protocol.DatagramEndpoint{
			Address: protocol.DatagramAddress{Type: protocol.AddressTypeIPv4, Bytes: address},
			Port:    uint16(value.Port),
		}, nil
	case *syscall.SockaddrInet6:
		if family != AddressFamilyIPv6 || value.ZoneId != 0 || value.Port <= 0 || value.Port > 65535 {
			return protocol.DatagramEndpoint{}, errUnsupportedSourceEndpoint
		}
		address := make([]byte, 16)
		copy(address, value.Addr[:])
		return protocol.DatagramEndpoint{
			Address: protocol.DatagramAddress{Type: protocol.AddressTypeIPv6, Bytes: address},
			Port:    uint16(value.Port),
		}, nil
	default:
		return protocol.DatagramEndpoint{}, errUnsupportedSourceEndpoint
	}
}
