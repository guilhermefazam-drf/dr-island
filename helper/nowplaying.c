// What is playing system-wide (Brave, Safari, Spotify, …), read through the private MediaRemote framework.
// Since macOS 15.4 MediaRemote only answers Apple-signed processes, so this library is not loaded by the app
// itself: it is loaded by /usr/bin/perl (which Apple signs) through nowplaying.pl, and prints one JSON line.
//
// Environment: NP_ART=1 also prints the artwork (base64); NP_CMD=<n> sends a command instead of reading
// (0 play, 1 pause, 2 toggle, 4 next, 5 previous).
#include <dlfcn.h>
#include <dispatch/dispatch.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <stdlib.h>

typedef void (^InfoHandler)(CFDictionaryRef info);
typedef void (*GetInfo)(dispatch_queue_t, InfoHandler);
typedef Boolean (*SendCommand)(int, CFDictionaryRef);
typedef void (*GetPlaying)(dispatch_queue_t, void (^)(Boolean));
typedef void (*GetClient)(dispatch_queue_t, void (^)(CFTypeRef));
typedef CFStringRef (*ClientBundle)(CFTypeRef);

static void print_string(CFStringRef s) {
    CFIndex n = CFStringGetMaximumSizeForEncoding(CFStringGetLength(s), kCFStringEncodingUTF8) + 1;
    char *buf = malloc(n);
    if (!buf || !CFStringGetCString(s, buf, n, kCFStringEncodingUTF8)) { printf("null"); free(buf); return; }
    putchar('"');
    for (char *p = buf; *p; p++) {
        if (*p == '"' || *p == '\\') { putchar('\\'); putchar(*p); }
        else if ((unsigned char)*p < 0x20) putchar(' ');
        else putchar(*p);
    }
    putchar('"');
    free(buf);
}

static void print_base64(CFDataRef data) {
    static const char t[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const UInt8 *b = CFDataGetBytePtr(data);
    CFIndex n = CFDataGetLength(data);
    putchar('"');
    for (CFIndex i = 0; i < n; i += 3) {
        unsigned v = b[i] << 16 | (i + 1 < n ? b[i + 1] << 8 : 0) | (i + 2 < n ? b[i + 2] : 0);
        putchar(t[v >> 18 & 63]); putchar(t[v >> 12 & 63]);
        putchar(i + 1 < n ? t[v >> 6 & 63] : '='); putchar(i + 2 < n ? t[v & 63] : '=');
    }
    putchar('"');
}

// Called by perl's DynaLoader as an XSUB; the arguments are ignored.
void run(void *a, void *b) {
    void *h = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    if (!h) { printf("{}\n"); return; }

    const char *cmd = getenv("NP_CMD");
    SendCommand send = dlsym(h, "MRMediaRemoteSendCommand");
    if (cmd && send) { Boolean ok = send(atoi(cmd), NULL); printf("{\"sent\":%d}\n", ok ? 1 : 0); return; }
    if (cmd) { printf("{\"sent\":-1}\n"); return; }

    GetInfo getInfo = dlsym(h, "MRMediaRemoteGetNowPlayingInfo");
    if (!getInfo) { printf("{}\n"); return; }
    int withArt = getenv("NP_ART") != NULL;
    // The playback rate alone is unreliable (some pages report 0 while playing), so ask the system too.
    __block int playing = -1;
    // Which app is playing (its bundle identifier), to label the source.
    static char bundle[256];
    bundle[0] = 0;
    GetClient getClient = dlsym(h, "MRMediaRemoteGetNowPlayingClient");
    ClientBundle clientBundle = dlsym(h, "MRNowPlayingClientGetBundleIdentifier");
    if (getClient && clientBundle) {
        dispatch_semaphore_t cs = dispatch_semaphore_create(0);
        getClient(dispatch_get_global_queue(0, 0), ^(CFTypeRef client) {
            if (client) { CFStringRef id = clientBundle(client); if (id) CFStringGetCString(id, bundle, 256, kCFStringEncodingUTF8); }
            dispatch_semaphore_signal(cs);
        });
        dispatch_semaphore_wait(cs, dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC));
    }
    GetPlaying getPlaying = dlsym(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    if (getPlaying) {
        dispatch_semaphore_t ps = dispatch_semaphore_create(0);
        getPlaying(dispatch_get_global_queue(0, 0), ^(Boolean p) { playing = p ? 1 : 0; dispatch_semaphore_signal(ps); });
        dispatch_semaphore_wait(ps, dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC));
    }
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    getInfo(dispatch_get_global_queue(0, 0), ^(CFDictionaryRef info) {
        printf("{");
        if (info) {
            CFTypeRef title = CFDictionaryGetValue(info, CFSTR("kMRMediaRemoteNowPlayingInfoTitle"));
            CFTypeRef artist = CFDictionaryGetValue(info, CFSTR("kMRMediaRemoteNowPlayingInfoArtist"));
            CFTypeRef rate = CFDictionaryGetValue(info, CFSTR("kMRMediaRemoteNowPlayingInfoPlaybackRate"));
            CFTypeRef art = CFDictionaryGetValue(info, CFSTR("kMRMediaRemoteNowPlayingInfoArtworkData"));
            printf("\"title\":"); if (title && CFGetTypeID(title) == CFStringGetTypeID()) print_string(title); else printf("null");
            printf(",\"artist\":"); if (artist && CFGetTypeID(artist) == CFStringGetTypeID()) print_string(artist); else printf("null");
            double r = 0;
            if (rate && CFGetTypeID(rate) == CFNumberGetTypeID()) CFNumberGetValue(rate, kCFNumberDoubleType, &r);
            printf(",\"rate\":%g,\"playing\":%d", r, playing);
            // Position and length, so the island can draw a progress bar. `timestamp` is when `elapsed` was true.
            CFTypeRef elapsed = CFDictionaryGetValue(info, CFSTR("kMRMediaRemoteNowPlayingInfoElapsedTime"));
            CFTypeRef duration = CFDictionaryGetValue(info, CFSTR("kMRMediaRemoteNowPlayingInfoDuration"));
            CFTypeRef stamp = CFDictionaryGetValue(info, CFSTR("kMRMediaRemoteNowPlayingInfoTimestamp"));
            double e = 0, d = 0;
            if (elapsed && CFGetTypeID(elapsed) == CFNumberGetTypeID()) CFNumberGetValue(elapsed, kCFNumberDoubleType, &e);
            if (duration && CFGetTypeID(duration) == CFNumberGetTypeID()) CFNumberGetValue(duration, kCFNumberDoubleType, &d);
            printf(",\"elapsed\":%g,\"duration\":%g", e, d);
            if (stamp && CFGetTypeID(stamp) == CFDateGetTypeID())
                printf(",\"timestamp\":%.3f", CFDateGetAbsoluteTime(stamp) + kCFAbsoluteTimeIntervalSince1970);
            if (bundle[0]) printf(",\"bundle\":\"%s\"", bundle);
            if (withArt && art && CFGetTypeID(art) == CFDataGetTypeID()) { printf(",\"artwork\":"); print_base64(art); }
        }
        printf("}\n");
        fflush(stdout);
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
}
