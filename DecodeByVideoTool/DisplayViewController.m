//
//  DisplayViewController.m
//  DecodeByVideoToolBox
//
//  Created by 陈剑 on 2021/12/15.
//

#import "DisplayViewController.h"
#import "CJAVPlayer/CJAVPlayer.h"


@interface DisplayViewController ()
{
    
    dispatch_queue_t queue;
    UIButton * playBtn;
    bool isVideoPlay;
    bool seekRequest;

    int64_t videoDuration;

    Float64 seekTime;
}


@property (nonatomic, strong) UIView * processView;
@property (nonatomic, strong) UIView * timeView;
@property (nonatomic, strong) UILabel * currentTimeLabel;
@property (nonatomic, strong) UILabel * totalTimeLabel;
@property (nonatomic, strong) CJAVPlayer * player;
@end

@implementation DisplayViewController



- (instancetype)initWithUrl:(NSString *)urlStr {


    if (self = [super init]) {
        self.player = [[CJAVPlayer alloc]initWithURLString:urlStr layerFrame:self.view.layer.frame];

        [self.view.layer addSublayer:self.player.playLayer];
        [self setUI];
    }
    return self;
}

- (void)setUI {
    UIBarButtonItem *leftItem1 = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(backAction)];//设置一个系统Item
    self.navigationItem.leftBarButtonItem = leftItem1;//添加到导航项的左按钮
    self.view.backgroundColor = [UIColor whiteColor];
    playBtn = [[UIButton alloc]initWithFrame:CGRectMake(self.view.center.x, self.view.center.y, 100, 100)];
    playBtn.selected = YES;
    [playBtn setTitle:@"play" forState:UIControlStateNormal];
    [playBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [playBtn addTarget:self action:@selector(playVideo:) forControlEvents:UIControlEventTouchUpInside];


    queue = dispatch_queue_create("thread", DISPATCH_QUEUE_SERIAL);

    //processView
    self.processView = [[UIView alloc]initWithFrame:CGRectMake(-self.view.frame.size.width + 40, self.view.frame.size.height - 100, self.view.frame.size.width, 40)];
    UIView * line = [[UIView alloc]initWithFrame:CGRectMake(0, 19, CGRectGetWidth(self.processView.frame) - 40, 2)];
    line.backgroundColor = [UIColor blackColor];
    [self.processView addSubview:line];
    UIView *panView = [[UIView alloc]initWithFrame:CGRectMake(CGRectGetMaxX(line.frame), 0, 40, 40)];
    panView.backgroundColor = [UIColor blackColor];
    panView.layer.cornerRadius = 20;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(pan:)];
    [panView addGestureRecognizer:pan];
    [self.processView addSubview:panView];

    //timeView
    self.timeView = [[UIView alloc]initWithFrame:CGRectMake(self.view.frame.size.width - 200, CGRectGetMinY(self.processView.frame) - 25, 200, 20)];

    self.totalTimeLabel  = [[UILabel alloc]initWithFrame:CGRectMake(100, 2, 100, 16)];
    self.totalTimeLabel.font = [UIFont systemFontOfSize:16];
    self.totalTimeLabel.textColor = [UIColor blackColor];

    [self.timeView addSubview:self.totalTimeLabel];

    self.currentTimeLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 2, 100, 16)];
    self.currentTimeLabel.font = [UIFont systemFontOfSize:16];
    self.currentTimeLabel.textColor = [UIColor blackColor];
    NSString *currentTimeText = [[NSString string]stringByAppendingString:[self getStringForTime:[self.player getCurrentTime]]];
    self.currentTimeLabel.text = currentTimeText;
    [self.timeView addSubview:self.currentTimeLabel];

    NSURL *rtmpURL = [[NSURL alloc]initWithString:@"rtmp://192.168.99.158/live/livestream.flv"];


    __weak typeof(self) weakSelf = self;
    [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 30) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf.currentTimeLabel.text = [strongSelf getStringForTime:CMTimeGetSeconds(time)];
            Float64 process = CMTimeGetSeconds(time) / [strongSelf.player getDuration] ;
            Float64 lineWidth = strongSelf.processView.frame.size.width - 40;
            CGRect frame = strongSelf.processView.frame;
            frame.origin.x = -(lineWidth - (lineWidth * process));
            strongSelf.processView.frame = frame;
        });
    }];

    [self.player play];
    NSString *totalTimeText = [self getStringForTime:[self.player getDuration]];
    self.totalTimeLabel.text = totalTimeText;
    [self.view addSubview:self.timeView];
    [self.view addSubview:self.processView];
    [self.view addSubview:playBtn];
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)playVideo:(UIButton *)sender {
    sender.selected = !sender.selected;
    if (sender.selected) {
        [self.player play];
    }else {
        [self.player pause];
    }
}

#pragma mark gestureMethod
- (void)pan:(UIPanGestureRecognizer  *)pan {

    if (pan.state == UIGestureRecognizerStateBegan) {

        [self.player pause];
    }

   // [self layerPause];


    CGFloat pointX = [pan translationInView:self.view].x;


    CGRect processFrame = self.processView.frame;

    if (processFrame.origin.x + pointX > 0) {
        processFrame.origin.x = 0;
    }else {
        processFrame.origin.x += pointX;
    }
    self.processView.frame = processFrame;


    [pan setTranslation:CGPointZero inView:self.view];

    float process = 1 - (-processFrame.origin.x / (self.view.frame.size.width - 40));

    seekTime = [self.player getDuration] * process;
    


    if (pan.state == UIGestureRecognizerStateEnded) {
        [self.player seekToTime:seekTime];
        [self.player play];
    }
}

- (NSString *)getStringForTime:(Float64)time {
    if (time == NAN) {
        return @"00:00";
    }

    int ceilTime = ceil(time);
    return [[NSString alloc]initWithFormat:@"%02d:%02d", ceilTime / 60,ceilTime % 60];
}

- (void)backAction {
    [self.player removePlayer];
//    [self.navigationController popViewControllerAnimated:YES];
    [self dismissViewControllerAnimated:YES completion:^{

    }];
}

- (void)dealloc {
    
}


@end
