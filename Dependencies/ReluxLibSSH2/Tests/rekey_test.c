#include <arpa/inet.h>
#include <libssh2.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <unistd.h>

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

int main(int argc, char **argv)
{
    struct sockaddr_in address;
    LIBSSH2_SESSION *session;
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

    session = libssh2_session_init();
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

    libssh2_session_set_blocking(session, 1);
    if(run_command(session, "printf client-rekey-ok", "client-rekey-ok", 15) ||
       run_command(session,
                   "dd if=/dev/zero bs=1024 count=512 2>/dev/null; "
                   "printf server-rekey-ok",
                   "server-rekey-ok", 512 * 1024) ||
       run_command(session, "printf post-server-rekey-ok",
                   "post-server-rekey-ok", 20))
        return 1;

    printf("client rekey completed after %d EAGAIN result(s); post-rekey "
           "channels succeeded\n",
           eagain_count);
    libssh2_session_disconnect(session, "test complete");
    libssh2_session_free(session);
    close(socket_fd);
    libssh2_exit();
    return 0;
}
