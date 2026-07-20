#include <arpa/inet.h>
#include <errno.h>
#include <libssh2.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

#define MAX_SERVER_KEX_EVENTS 64

struct test_context {
    int socket_fd;
    int hold_reads;
    int fail_on_server_kex_start;
    LIBSSH2_SERVER_KEX_STATUS events[MAX_SERVER_KEX_EVENTS];
    size_t event_count;
};

static long long monotonic_milliseconds(void)
{
    struct timespec now;

    if(clock_gettime(CLOCK_MONOTONIC, &now))
        return -1;
    return (long long)now.tv_sec * 1000 + now.tv_nsec / 1000000;
}

static void sleep_milliseconds(long milliseconds)
{
    struct timespec duration;

    duration.tv_sec = milliseconds / 1000;
    duration.tv_nsec = (milliseconds % 1000) * 1000000;
    while(nanosleep(&duration, &duration) && errno == EINTR)
        ;
}

static LIBSSH2_RECV_FUNC(test_receive)
{
    struct test_context *context = *abstract;
    ssize_t count;

    if(context->hold_reads)
        return -EAGAIN;

    count = recv(socket, buffer, length, flags);
    if(count < 0) {
        if(errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK)
            return -EAGAIN;
        return -errno;
    }
    return count;
}

static void observe_server_kex(
    LIBSSH2_SESSION *session,
    const LIBSSH2_SERVER_KEX_STATUS *status,
    void *abstract)
{
    struct test_context *context = abstract;

    (void)session;
    if(context->event_count < MAX_SERVER_KEX_EVENTS)
        context->events[context->event_count++] = *status;
    if(context->fail_on_server_kex_start &&
       status->state == LIBSSH2_SERVER_KEX_STARTED)
        shutdown(context->socket_fd, SHUT_RDWR);
}

static int wait_socket(int socket_fd, LIBSSH2_SESSION *session)
{
    fd_set read_fds;
    fd_set write_fds;
    struct timeval timeout = {5, 0};
    int directions = libssh2_session_block_directions(session);

    FD_ZERO(&read_fds);
    FD_ZERO(&write_fds);
    if(directions & LIBSSH2_SESSION_BLOCK_INBOUND)
        FD_SET(socket_fd, &read_fds);
    if(directions & LIBSSH2_SESSION_BLOCK_OUTBOUND)
        FD_SET(socket_fd, &write_fds);
    return select(socket_fd + 1, &read_fds, &write_fds, NULL, &timeout);
}

static int run_command(LIBSSH2_SESSION *session, const char *command,
                       const char *required_suffix, size_t minimum_bytes)
{
    LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(session);
    char buffer[4096];
    char tail[128] = {0};
    size_t total = 0;
    size_t tail_length = 0;
    size_t suffix_length = strlen(required_suffix);
    ssize_t count;

    if(!channel || libssh2_channel_exec(channel, command))
        return 1;

    while((count = libssh2_channel_read(channel, buffer, sizeof(buffer))) > 0) {
        size_t copy = (size_t)count;
        size_t keep;

        if(copy > sizeof(tail))
            copy = sizeof(tail);
        keep = tail_length;
        if(keep + copy > sizeof(tail))
            keep = sizeof(tail) - copy;
        if(keep && keep != tail_length)
            memmove(tail, tail + tail_length - keep, keep);
        memcpy(tail + keep, buffer + count - copy, copy);
        tail_length = keep + copy;
        total += (size_t)count;
    }

    if(count < 0 || libssh2_channel_close(channel) ||
       libssh2_channel_get_exit_status(channel) != 0 ||
       libssh2_channel_free(channel) || total < minimum_bytes ||
       tail_length < suffix_length ||
       memcmp(tail + tail_length - suffix_length, required_suffix,
              suffix_length)) {
        fprintf(stderr, "command failed: count=%zd total=%zu\n", count, total);
        return 1;
    }
    return 0;
}

static int run_global_request(
    LIBSSH2_SESSION *session,
    int socket_fd,
    const char *name,
    const unsigned char *payload,
    size_t payload_length,
    LIBSSH2_GLOBAL_REQUEST_REPLY *reply,
    int *eagain_count)
{
    int rc;

    do {
        rc = libssh2_session_global_request(
            session, name, strlen(name), payload, payload_length, reply);
        if(rc == LIBSSH2_ERROR_EAGAIN) {
            ++*eagain_count;
            if(wait_socket(socket_fd, session) <= 0)
                return LIBSSH2_ERROR_TIMEOUT;
        }
    } while(rc == LIBSSH2_ERROR_EAGAIN);
    return rc;
}

static int test_global_requests(
    LIBSSH2_SESSION *session,
    int socket_fd,
    struct test_context *context)
{
    static const char keepalive_name[] = "keepalive@openssh.com";
    static const char other_name[] = "relux-probe@example.invalid";
    static const unsigned char payload[] = {0, 0, 0, 1, 'x'};
    unsigned char oversized_payload[
        LIBSSH2_GLOBAL_REQUEST_MAX_PAYLOAD_LENGTH + 1] = {0};
    LIBSSH2_GLOBAL_REQUEST_REPLY reply;
    long long started;
    long long elapsed;
    int eagain_count = 0;
    int misses = 0;
    int rc;

    context->hold_reads = 1;
    started = monotonic_milliseconds();
    rc = libssh2_session_global_request(
        session, keepalive_name, sizeof(keepalive_name) - 1,
        NULL, 0, &reply);
    if(rc != LIBSSH2_ERROR_EAGAIN ||
       reply != LIBSSH2_GLOBAL_REQUEST_REPLY_NONE)
        return 1;
    sleep_milliseconds(25);
    context->hold_reads = 0;
    rc = run_global_request(
        session, socket_fd, keepalive_name, NULL, 0, &reply, &eagain_count);
    elapsed = monotonic_milliseconds() - started;
    if(rc || reply == LIBSSH2_GLOBAL_REQUEST_REPLY_NONE || elapsed < 20 ||
       elapsed > 5000)
        return 1;

    rc = run_global_request(
        session, socket_fd, other_name, payload, sizeof(payload),
        &reply, &eagain_count);
    if(rc || reply == LIBSSH2_GLOBAL_REQUEST_REPLY_NONE)
        return 1;

    rc = libssh2_session_global_request(
        session, other_name, sizeof(other_name) - 1,
        oversized_payload, sizeof(oversized_payload), &reply);
    if(rc != LIBSSH2_ERROR_INVAL)
        return 1;

    libssh2_session_set_read_timeout(session, 1);
    context->hold_reads = 1;
    do {
        rc = libssh2_session_global_request(
            session, keepalive_name, sizeof(keepalive_name) - 1,
            NULL, 0, &reply);
    } while(rc == LIBSSH2_ERROR_EAGAIN &&
            !(libssh2_session_block_directions(session) &
              LIBSSH2_SESSION_BLOCK_INBOUND));
    if(rc != LIBSSH2_ERROR_EAGAIN)
        return 1;

    rc = libssh2_session_global_request(
        session, other_name, sizeof(other_name) - 1,
        payload, sizeof(payload), &reply);
    if(rc != LIBSSH2_ERROR_BAD_USE)
        return 1;

    sleep_milliseconds(1100);
    rc = libssh2_session_global_request(
        session, keepalive_name, sizeof(keepalive_name) - 1,
        NULL, 0, &reply);
    if(rc != LIBSSH2_ERROR_TIMEOUT ||
       reply != LIBSSH2_GLOBAL_REQUEST_REPLY_NONE)
        return 1;
    ++misses;

    context->hold_reads = 0;
    rc = run_global_request(
        session, socket_fd, keepalive_name, NULL, 0, &reply, &eagain_count);
    libssh2_session_set_read_timeout(session, 60);
    if(rc || reply == LIBSSH2_GLOBAL_REQUEST_REPLY_NONE || misses != 1)
        return 1;

    printf("reply-correlated global requests completed with RTT=%lldms, "
           "%d EAGAIN result(s), and %d deterministic timeout/miss\n",
           elapsed, eagain_count + 1, misses);
    return 0;
}

static int validate_server_kex_events(
    LIBSSH2_SESSION *session,
    const struct test_context *context,
    size_t first_event,
    LIBSSH2_SERVER_KEX_STATE terminal_state)
{
    LIBSSH2_SERVER_KEX_STATUS status;
    libssh2_uint64_t prior_generation = first_event ?
        context->events[first_event - 1].generation : 0;
    size_t index;

    if(context->event_count <= first_event ||
       (context->event_count - first_event) % 2)
        return 1;

    for(index = first_event; index < context->event_count; index += 2) {
        const LIBSSH2_SERVER_KEX_STATUS *started = &context->events[index];
        const LIBSSH2_SERVER_KEX_STATUS *terminal =
            &context->events[index + 1];

        if(started->state != LIBSSH2_SERVER_KEX_STARTED ||
           started->generation != prior_generation + 1 ||
           terminal->state != terminal_state ||
           terminal->generation != started->generation)
            return 1;
        prior_generation = terminal->generation;
    }

    if(libssh2_session_server_kex_status(session, &status) ||
       status.state != terminal_state ||
       status.generation != prior_generation)
        return 1;
    return 0;
}

int main(int argc, char **argv)
{
    struct sockaddr_in address;
    LIBSSH2_SESSION *session;
    struct test_context context;
    LIBSSH2_SERVER_KEX_STATUS initial_status;
    int socket_fd;
    int rc;
    int eagain_count = 0;

    if(argc != 6) {
        fprintf(stderr, "usage: %s host port user public-key private-key\n",
                argv[0]);
        return 2;
    }
    if(libssh2_init(0))
        return 1;

    memset(&context, 0, sizeof(context));

    socket_fd = socket(AF_INET, SOCK_STREAM, 0);
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_port = htons((unsigned short)atoi(argv[2]));
    if(socket_fd < 0 ||
       inet_pton(AF_INET, argv[1], &address.sin_addr) != 1 ||
       connect(socket_fd, (struct sockaddr *)&address, sizeof(address))) {
        perror("connect");
        return 1;
    }

    context.socket_fd = socket_fd;
    session = libssh2_session_init_ex(NULL, NULL, NULL, &context);
    if(session) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-strict"
        libssh2_session_callback_set2(
            session, LIBSSH2_CALLBACK_RECV,
            (libssh2_cb_generic *)test_receive);
#pragma clang diagnostic pop
        libssh2_session_server_kex_observer_set(
            session, observe_server_kex, &context);
    }
    if(!session || libssh2_session_handshake(session, socket_fd) ||
       libssh2_userauth_publickey_fromfile(session, argv[3], argv[4], argv[5],
                                           NULL)) {
        fprintf(stderr, "handshake/authentication failed: %d\n",
                session ? libssh2_session_last_errno(session) : -1);
        return 1;
    }

    libssh2_session_set_blocking(session, 0);
    do {
        rc = libssh2_session_rekey(session);
        if(rc == LIBSSH2_ERROR_EAGAIN) {
            ++eagain_count;
            if(wait_socket(socket_fd, session) <= 0) {
                fprintf(stderr, "timed out waiting for client rekey\n");
                return 1;
            }
        }
    } while(rc == LIBSSH2_ERROR_EAGAIN);
    if(rc || eagain_count == 0) {
        fprintf(stderr, "client rekey failed: rc=%d eagain=%d\n", rc,
                eagain_count);
        return 1;
    }

    if(libssh2_session_server_kex_status(session, &initial_status) ||
       initial_status.state != LIBSSH2_SERVER_KEX_NONE ||
       initial_status.generation != 0 ||
       test_global_requests(session, socket_fd, &context))
        return 1;

    libssh2_session_set_blocking(session, 1);
    if(run_command(session, "printf client-rekey-ok", "client-rekey-ok", 15) ||
       run_command(session,
                   "dd if=/dev/zero bs=1024 count=192 2>/dev/null; "
                   "printf server-rekey-ok",
                   "server-rekey-ok", 192 * 1024) ||
       validate_server_kex_events(
           session, &context, 0, LIBSSH2_SERVER_KEX_SUCCEEDED) ||
       run_command(session, "printf post-server-rekey-ok",
                   "post-server-rekey-ok", 20))
        return 1;

    {
        size_t first_failure_event = context.event_count;

        context.fail_on_server_kex_start = 1;
        if(!run_command(session,
                        "dd if=/dev/zero bs=1024 count=128 2>/dev/null; "
                        "printf unexpected",
                        "unexpected", 128 * 1024) ||
           validate_server_kex_events(
               session, &context, first_failure_event,
               LIBSSH2_SERVER_KEX_FAILED))
            return 1;
    }

    printf("client rekey completed after %d EAGAIN result(s); post-rekey "
           "channels succeeded; %zu server-KEX transitions observed\n",
           eagain_count, context.event_count);
    libssh2_session_free(session);
    close(socket_fd);
    libssh2_exit();
    return 0;
}
