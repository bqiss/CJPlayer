//
//  BufferQueue.m
//  DecodeByVideoTool
//
//  Created by 陈剑 on 2022/1/12.
//

#import "PacketQueue.h"
#define MIN_PKT_DURATION 15
AVPacket flushPacket;

typedef struct MyPacketList {
    MyPacket pkt;
    struct MyPacketList *next;
}MyPacketList;

struct Queue {
    MyPacketList *first_pkt, *last_pkt;
    MyPacketList* recycle_pkt;
    int count;
    int recycle_count;
    int alloc_count;
    int size;
    int serial;
    int nb_packets;
    int64_t duration;
};

@interface PacketQueue ()
{
    struct Queue *queue;
    pthread_mutex_t mutex;
}

@end

@implementation PacketQueue
- (instancetype)init {
    if (self = [super init]) {
        //init flush packet
        av_init_packet(&flushPacket);
        flushPacket.data = (uint8_t *)&flushPacket;

        queue = (struct Queue*)malloc(sizeof(struct Queue));
        [self QueueInit:queue];
        pthread_mutex_init(&mutex, NULL);
    }
    return self;
}

- (void)QueueInit:(struct Queue*)queue {
    queue->first_pkt = NULL;
    queue->last_pkt = NULL;
    queue->recycle_pkt = NULL;
    queue->count = 0;
    queue->serial = 0;
    queue -> size = 0;
    queue -> alloc_count = 0;
    queue -> recycle_count = 0;
    queue -> nb_packets = 0;
    queue -> duration = 0;
}

- (int) QueueEmpty {
    return queue -> count <= 0;
}

- (int) packet_queue_get:(MyPacket *)pkt {
    MyPacketList *pkt1;
    int ret;
    pthread_mutex_lock(&mutex);
    pkt1 = queue->first_pkt;
    if (pkt1) {
        queue->first_pkt = pkt1->next;
        if (!queue->first_pkt)
            queue->last_pkt = NULL;
        queue->nb_packets--;
        queue->size -= pkt1->pkt.packet.size + sizeof(*pkt1);
        queue->duration -= FFMAX(pkt1->pkt.packet.duration, MIN_PKT_DURATION);
        *pkt = pkt1->pkt;

        pkt1->next = queue->recycle_pkt;
        queue->recycle_pkt = pkt1;
        ret = 1;
    } else {
        ret = 0;
    }

    pthread_mutex_unlock(&mutex);
    return ret;
}

- (void)packet_queue_flush
{
    MyPacketList *pkt, *pkt1;

    pthread_mutex_lock(&mutex);
    for (pkt = queue->first_pkt; pkt; pkt = pkt1) {
        pkt1 = pkt->next;
        av_packet_unref(&pkt -> pkt.packet);
        pkt->next = queue->recycle_pkt;
        queue->recycle_pkt = pkt;
    }
    queue->last_pkt = NULL;
    queue->first_pkt = NULL;
    queue->nb_packets = 0;
    queue->size = 0;
    queue->duration = 0;
    pthread_mutex_unlock(&mutex);
}


- (int) packet_queue_put_nullpacket:(int)streamIndex
{
    AVPacket pkt1, *pkt = &pkt1;
    av_init_packet(pkt);
    pkt->data = NULL;
    pkt->size = 0;
    pkt->stream_index = streamIndex;

    MyPacket myPacket = {0};
    myPacket.packet = *pkt;
    myPacket.serial = queue -> serial;
    return [self packet_queue_put:&myPacket];
}

- (int)packet_queue_put:(MyPacket *)pkt
{
    int ret;

    pthread_mutex_lock(&mutex);
    ret = [self packet_queue_put_private:pkt];
    pthread_mutex_unlock(&mutex);

    if (pkt -> packet.data != flushPacket.data && ret < 0)
        av_packet_unref(&pkt -> packet);

    return ret;
}

- (void) packet_queue_destroy
{

    [self packet_queue_flush];

    pthread_mutex_lock(&mutex);
    while(queue->recycle_pkt) {
        MyPacketList *pkt = queue->recycle_pkt;
        if (pkt)
            queue->recycle_pkt = pkt->next;
        av_freep(&pkt);
    }
    free(queue);
    pthread_mutex_unlock(&mutex);
    pthread_mutex_destroy(&mutex);
}

- (int)GetQueueCount {
    return queue -> count;
}

- (pthread_mutex_t)getMutex {
    return mutex;
}

- (int)getQueueSize {
    return queue -> size;
}

- (int)getQueuePacketCount {
    return queue -> count;
}

#pragma mark private

//put the packet into the queue
- (int)packet_queue_put_private:(MyPacket *)pkt {
    MyPacketList *pkt1;


//    if (queue->abort_request)
//       return -1;

    pkt1 = queue->recycle_pkt;
    if (pkt1) {
        queue->recycle_pkt = pkt1->next;
        queue->recycle_count++;
    } else {
        queue->alloc_count++;
        pkt1 = (MyPacketList*)av_malloc(sizeof(MyPacketList));
    }

    if (!pkt1)
        return -1;
    pkt1->pkt = *pkt;
    pkt1->next = NULL;
    if (pkt->packet.data == flushPacket.data)
        queue->serial++;
    pkt1->pkt.serial = queue->serial;

    if (!queue->last_pkt)
        queue->first_pkt = pkt1;
    else
        queue->last_pkt->next = pkt1;
    queue->last_pkt = pkt1;
    queue->nb_packets++;
    queue->size += pkt1->pkt.packet.size + sizeof(*pkt1);

    queue->duration += FFMAX(pkt1->pkt.packet.duration, MIN_PKT_DURATION);

    return 0;
}





@end
