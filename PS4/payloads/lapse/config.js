// PS4 Lapse Configuration
// Ported from PS5 version for Netflix n Hack

var FW_VERSION = "";
var IS_PS4 = true;

var PAGE_SIZE = 0x4000;
var PHYS_PAGE_SIZE = 0x1000;

var LIBKERNEL_HANDLE = 0x2001n;

// Socket constants (only ones not in inject_auto.js)
// Already in inject_auto.js: AF_INET, AF_INET6, SOCK_STREAM, SOCK_DGRAM,
//   IPPROTO_UDP, IPPROTO_IPV6, IPV6_PKTINFO, SOL_SOCKET, SO_REUSEADDR
var AF_UNIX = 1n;
var IPPROTO_TCP = 6n;
var SO_LINGER = 0x80n;

// IPv6 socket options (IPV6_PKTINFO already in inject_auto.js)
var IPV6_NEXTHOP = 48n;
var IPV6_RTHDR = 51n;
var IPV6_TCLASS = 61n;
var IPV6_2292PKTOPTIONS = 25n;

// TCP socket options
var TCP_INFO = 32n;
var TCPS_ESTABLISHED = 4n;

// All syscalls from lapse.py (PS4)
// (SYSCALL object is already defined in inject.js, we just add properties)
SYSCALL.unlink = 0xAn;              // 10
SYSCALL.pipe = 42n;                 // 42
SYSCALL.getpid = 20n;               // 20
SYSCALL.getuid = 0x18n;             // 24
SYSCALL.kill = 37n;                 // 37
SYSCALL.connect = 98n;              // 98
SYSCALL.munmap = 0x49n;             // 73
SYSCALL.mprotect = 0x4An;           // 74
SYSCALL.getsockopt = 0x76n;         // 118
SYSCALL.socketpair = 0x87n;         // 135
SYSCALL.nanosleep = 0xF0n;          // 240
SYSCALL.sched_yield = 0x14Bn;       // 331
SYSCALL.thr_exit = 0x1AFn;          // 431
SYSCALL.thr_self = 0x1B0n;          // 432
SYSCALL.thr_new = 0x1C7n;           // 455
SYSCALL.rtprio_thread = 0x1D2n;     // 466
SYSCALL.mmap = 477n;                // 477
SYSCALL.cpuset_getaffinity = 0x1E7n; // 487
SYSCALL.cpuset_setaffinity = 0x1E8n; // 488
SYSCALL.jitshm_create = 0x215n;     // 533
SYSCALL.jitshm_alias = 0x216n;      // 534
SYSCALL.evf_create = 0x21An;        // 538
SYSCALL.evf_delete = 0x21Bn;        // 539
SYSCALL.evf_set = 0x220n;           // 544
SYSCALL.evf_clear = 0x221n;         // 545
SYSCALL.is_in_sandbox = 0x249n;     // 585
SYSCALL.dlsym = 0x24Fn;             // 591
SYSCALL.thr_suspend_ucontext = 0x278n; // 632
SYSCALL.thr_resume_ucontext = 0x279n; // 633
SYSCALL.aio_multi_delete = 0x296n;  // 662
SYSCALL.aio_multi_wait = 0x297n;    // 663
SYSCALL.aio_multi_poll = 0x298n;    // 664
SYSCALL.aio_multi_cancel = 0x29An;  // 666
SYSCALL.aio_submit_cmd = 0x29Dn;    // 669
SYSCALL.kexec = 0x295n;             // 661

var MAIN_CORE = 4;  // Same as yarpe
var MAIN_RTPRIO = 0x100;
var NUM_WORKERS = 2;
var NUM_GROOMS = 0x200;
var NUM_HANDLES = 0x100;
var NUM_SDS = 64;
var NUM_SDS_ALT = 48;
var NUM_RACES = 100;
var NUM_ALIAS = 100;
var LEAK_LEN = 16;
var NUM_LEAKS = 32;
var NUM_CLOBBERS = 8;
var MAX_AIO_IDS = 0x80;

var AIO_CMD_READ = 1n;
var AIO_CMD_FLAG_MULTI = 0x1000n;
var AIO_CMD_MULTI_READ = 0x1001n;
var AIO_CMD_WRITE = 2n;
var AIO_STATE_COMPLETE = 3n;
var AIO_STATE_ABORTED = 4n;

var SCE_KERNEL_ERROR_ESRCH = 0x80020003n;

var RTP_SET = 1n;
var PRI_REALTIME = 2n;

// TCP info structure size for getsockopt
var size_tcp_info = 0xEC;

var block_fd = 0xffffffffffffffffn;
var unblock_fd = 0xffffffffffffffffn;
var block_id = -1n;
var groom_ids = null;
var sds = null;
var sds_alt = null;
var prev_core = -1;
var prev_rtprio = 0n;
var ready_signal = 0n;
var deletion_signal = 0n;
var pipe_buf = 0n;

var saved_fpu_ctrl = 0;
var saved_mxcsr = 0;

function sysctlbyname(name, oldp, oldp_len, newp, newp_len) {
    const translate_name_mib = malloc(0x8);
    const buf_size = 0x70;
    const mib = malloc(buf_size);
    const size = malloc(0x8);

    write64_uncompressed(translate_name_mib, 0x300000000n);
    write64_uncompressed(size, BigInt(buf_size));

    const name_addr = alloc_string(name);
    const name_len = BigInt(name.length);

    if (syscall(SYSCALL.sysctl, translate_name_mib, 2n, mib, size, name_addr, name_len) === 0xffffffffffffffffn) {
        throw new Error("failed to translate sysctl name to mib (" + name + ")");
    }

    if (syscall(SYSCALL.sysctl, mib, 2n, oldp, oldp_len, newp, newp_len) === 0xffffffffffffffffn) {
        return false;
    }

    return true;
}
