#ifdef PLATFORM_IOS

#import <Foundation/Foundation.h>
#import <utility>
#import <cstdio>
#import <cstdarg>
#import <fstream>

#include "platform_ios.h"
#include "ViewController.h"

static ViewController* viewController;
NSURLSession* defaultSession;
static NSMutableString* s_resourceRoot = NULL;

void init(ViewController* _controller) {

    viewController = _controller;

    /* Setup NSURLSession configuration : cache path and size */
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSString *cachePath = @"/tile_cache";
    NSURLCache *tileCache = [[NSURLCache alloc] initWithMemoryCapacity: 4 * 1024 * 1024 diskCapacity: 30 * 1024 * 1024 diskPath: cachePath];
    defaultConfigObject.URLCache = tileCache;
    defaultConfigObject.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
    defaultConfigObject.timeoutIntervalForRequest = 30;
    defaultConfigObject.timeoutIntervalForResource = 60;

    /* create a default NSURLSession using the defaultConfigObject*/
    defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject ];

}

void logMsg(const char* fmt, ...) {

    va_list args;
    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);

}

void requestRender() {

    [viewController renderOnce];

}

void setContinuousRendering(bool _isContinuous) {

    [viewController setContinuous:_isContinuous];

}

bool isContinuousRendering() {

    return [viewController continuous];

}

std::string setResourceRoot(const char* _path) {

    NSString* path = [NSString stringWithUTF8String:_path];

    if (*_path != '/') {
        NSString* resources = [[NSBundle mainBundle] resourcePath];
        path = [resources stringByAppendingPathComponent:path];
    }

    s_resourceRoot = [ [path stringByDeletingLastPathComponent] mutableCopy];

    return std::string([[path lastPathComponent] UTF8String]);

}

NSString* resolvePath(const char* _path, PathType _type) {

    if (s_resourceRoot == NULL) {
        setResourceRoot(".");
    }

    NSString* path = [NSString stringWithUTF8String:_path];

    switch (_type) {
    case PathType::internal:
        return [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:path];
    case PathType::resource:
        return [s_resourceRoot stringByAppendingPathComponent:path];
    case PathType::absolute:
        return path;
    }
}

std::string stringFromFile(const char* _path, PathType _type) {

    NSString* path = resolvePath(_path, _type);
    NSString* str = [NSString stringWithContentsOfFile:path
                                          usedEncoding:NULL
                                                 error:NULL];

    if (str == nil) {
        logMsg("Failed to read file at path: %s\n", [path UTF8String]);
        return std::string();
    }

    return std::string([str UTF8String]);
}

unsigned char* bytesFromFile(const char* _path, PathType _type, unsigned int* _size) {

    NSString* path = resolvePath(_path, _type);
    NSMutableData* data = [NSMutableData dataWithContentsOfFile:path];

    if (data == nil) {
        logMsg("Failed to read file at path: %s\n", [path UTF8String]);
        *_size = 0;
        return nullptr;
    }

    *_size = data.length;
    unsigned char* ptr = (unsigned char*)malloc(*_size);
    [data getBytes:ptr length:*_size];

    return ptr;
}

// No system fonts implementation (yet!)
std::string systemFontPath(const std::string& _name, const std::string& _weight, const std::string& _face) {
    return "";
}

// No system fonts fallback implementation (yet!)
std::string systemFontFallbackPath(int _importance, int _weightHint) {
    return "";
}

bool startUrlRequest(const std::string& _url, UrlCallback _callback) {

    NSString* nsUrl = [NSString stringWithUTF8String:_url.c_str()];

    void (^handler)(NSData*, NSURLResponse*, NSError*) = ^void (NSData* data, NSURLResponse* response, NSError* error) {

        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;

        int statusCode = [httpResponse statusCode];

        std::vector<char> rawDataVec;

        if (error != nil) {

            LOGE("Response \"%s\" with error \"%s\".", response, [error.localizedDescription UTF8String]);

        } else if (statusCode < 200 || statusCode >= 300) {

            LOGE("Unsuccessful status code %d: \"%s\" from: %s",
                statusCode,
                [[NSHTTPURLResponse localizedStringForStatusCode: statusCode] UTF8String],
                [response.URL.absoluteString UTF8String]);
            _callback(std::move(rawDataVec));

        } else {

            int dataLength = [data length];
            rawDataVec.resize(dataLength);
            memcpy(rawDataVec.data(), (char *)[data bytes], dataLength);
            _callback(std::move(rawDataVec));

        }

    };

    NSURLSessionDataTask* dataTask = [defaultSession dataTaskWithURL:[NSURL URLWithString:nsUrl]
                                                    completionHandler:handler];

    [dataTask resume];

    return true;

}

void cancelUrlRequest(const std::string& _url) {

    NSString* nsUrl = [NSString stringWithUTF8String:_url.c_str()];

    [defaultSession getTasksWithCompletionHandler:^(NSArray* dataTasks, NSArray* uploadTasks, NSArray* downloadTasks) {
        for(NSURLSessionTask* task in dataTasks) {
            if([[task originalRequest].URL.absoluteString isEqualToString:nsUrl]) {
                [task cancel];
                break;
            }
        }
    }];

}

void setCurrentThreadPriority(int priority) {}

void initGLExtensions() {}

#endif //PLATFORM_IOS
