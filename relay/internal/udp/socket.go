package udp

import (
	"errors"
	"sync"
	"syscall"
)

// AddressFamily is the finite set of UDP descriptor families supported by
// relay protocol v1.
type AddressFamily uint8

const (
	AddressFamilyIPv4 AddressFamily = 4
	AddressFamilyIPv6 AddressFamily = 6
)

func (f AddressFamily) valid() bool {
	return f == AddressFamilyIPv4 || f == AddressFamilyIPv6
}

var errDescriptorClosed = errors.New("udp descriptor closed")

// Socket owns one nonblocking UDP descriptor. UseDescriptor and Close must be
// mutually safe: once Close returns, a later UseDescriptor callback must not
// observe a recycled descriptor number.
type Socket interface {
	UseDescriptor(func(descriptor int) error) error
	Close() error
}

// SocketFactory creates unconnected family-specific UDP sockets. A factory may
// return both a socket and an error when initialization partially succeeded;
// the registry closes that socket before returning the finite failure.
type SocketFactory interface {
	Open(AddressFamily) (Socket, error)
}

// SystemSocketFactory creates an unbound, unconnected UDP socket. It does not
// call bind or listen: a later sendto operation causes the kernel to choose an
// unprivileged ephemeral source port. This keeps registry creation from
// exposing a public inbound UDP service.
type SystemSocketFactory struct{}

func (SystemSocketFactory) Open(family AddressFamily) (Socket, error) {
	domain := syscall.AF_INET
	if family == AddressFamilyIPv6 {
		domain = syscall.AF_INET6
	} else if family != AddressFamilyIPv4 {
		return nil, syscall.EAFNOSUPPORT
	}

	descriptor, err := syscall.Socket(domain, syscall.SOCK_DGRAM, syscall.IPPROTO_UDP)
	if err != nil {
		return nil, err
	}
	socket := &systemSocket{descriptor: descriptor}
	if err := syscall.SetNonblock(descriptor, true); err != nil {
		_ = socket.Close()
		return nil, err
	}
	syscall.CloseOnExec(descriptor)
	if family == AddressFamilyIPv6 {
		if err := syscall.SetsockoptInt(descriptor, syscall.IPPROTO_IPV6, syscall.IPV6_V6ONLY, 1); err != nil {
			_ = socket.Close()
			return nil, err
		}
	}
	return socket, nil
}

type systemSocket struct {
	mu         sync.Mutex
	descriptor int
	closed     bool
}

func (s *systemSocket) UseDescriptor(operation func(int) error) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return errDescriptorClosed
	}
	return operation(s.descriptor)
}

func (s *systemSocket) Close() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return nil
	}
	s.closed = true
	return syscall.Close(s.descriptor)
}
