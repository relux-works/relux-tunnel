package udp

import "time"

// MonotonicClock supplies deadlines without wall-clock arithmetic. time.Time
// values returned by the production clock retain Go's monotonic component.
type MonotonicClock interface {
	Now() time.Time
	NewTimer(time.Duration) MonotonicTimer
}

type MonotonicTimer interface {
	C() <-chan time.Time
	Stop() bool
}

type systemClock struct{}

func (systemClock) Now() time.Time { return time.Now() }

func (systemClock) NewTimer(duration time.Duration) MonotonicTimer {
	return systemTimer{timer: time.NewTimer(duration)}
}

type systemTimer struct {
	timer *time.Timer
}

func (t systemTimer) C() <-chan time.Time { return t.timer.C }
func (t systemTimer) Stop() bool          { return t.timer.Stop() }
