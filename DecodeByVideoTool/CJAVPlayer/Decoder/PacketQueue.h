//
//  BufferQueue.h
//  DecodeByVideoTool
//
//  Created by 陈剑 on 2022/1/12.
//

#import <Foundation/Foundation.h>
#import <pthread.h>
// FFmpeg Header File
#ifdef __cplusplus
extern "C" {
#endif

#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#include "libavutil/avutil.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#include "libavutil/opt.h"
#include "libavutil/mathematics.h"
#include "libavutil/time.h"
#include "avstring.h"

#ifdef __cplusplus
};
#endif
NS_ASSUME_NONNULL_BEGIN
extern AVPacket flushPacket;
typedef struct MyPacket {
    int serial;
    BOOL isNeedResetTimeBase;
    AVPacket packet;
}MyPacket;

@interface PacketQueue : NSObject
- (pthread_mutex_t)getMutex;
- (int)getQueueSize;
- (int)getQueuePacketCount;

- (int) packet_queue_put:(MyPacket *)pkt;
- (int) packet_queue_put_nullpacket:(int)streamIndex;
- (void) packet_queue_flush;
- (int) packet_queue_get:(MyPacket *)pkt;
@end

NS_ASSUME_NONNULL_END
