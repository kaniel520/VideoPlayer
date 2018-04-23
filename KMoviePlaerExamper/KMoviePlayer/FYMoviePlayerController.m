//
//  FYMoviePlayerController.m
//  KMoviePlaerExamper
//
//  Created by Mac on 14-7-18.
//  Copyright (c) 2014年 FengYingOnline. All rights reserved.
//

#import "FYMoviePlayerController.h"
#import "KxMovieDecoder.h"
#import "KxAudioManager.h"
#import "KxMovieGLView.h"
#import "KxLogger.h"


// 当缩放比例发生改变时发送此通知
NSString *const FYMoviePlayerControllerScalingModeDidChangeNotification = @"FYMoviePlayerControllerScalingModeDidChange";

// 当视频播放准备完毕时发送此通知
NSString *const FYMoviePlayerControllerDidPrepareNotification = @"FYMoviePlayerControllerDidPrepare";

// 当视频播放结束或者用户退出时发送此通知
NSString *const FYMoviePlayerControllerPlaybackDidFinishNotification = @"FYMoviePlayerControllerPlaybackDidFinished";

// 当播放状态发生改变时发送此通知
NSString *const FYMoviePlayerControllerPlaybackStateDidChangeNotification = @"FYMoviePlayerControllerPlaybackStateDidChanege";

// 当视频开始网络缓冲时发送此通知
NSString *const FYMoviePlayerControllerStartCachingNotification = @"FYMoviePlayerControllerStartCaching";

// 当视频结束网络缓冲时发送此通知
NSString *const FYMoviePlayerControllerDidFinishedCachingNotification = @"FYMoviePlayerControllerDidFinishedCaching";

// 当前视频播放发生改变时发送此通知 视频加载成功发送此通知
NSString *const FYMoviePlayerControllerNowPlayingMovieDidChangeNotification = @"FYMoviePlayerControllerNowPlayingMovieDidChange";

// 当前视频播放位置发生改变发送此通知
NSString *const FYMoviePlayerControllerPlaybackPosDidChangeNotification = @"FYMoviePlayerControllerPlaybackPosDidChange";

// 错误通知
NSString * const FYMoviePlayerControllerErrorNotification = @"FYMoviePlayerControllerError";

/// 错误描述
NSString * const KMP_DIC_KEY_ERROR_DESCRIPTION = @"mKeyErrorDescription";

/// 参数配置信息
NSString * const FYParameterMinBufferedDuration = @"KxMovieParameterMinBufferedDuration";
NSString * const FYParameterMaxBufferedDuration = @"KxMovieParameterMaxBufferedDuration";
NSString * const FYParameterDisableDeinterlacing = @"KxMovieParameterDisableDeinterlacing";

// 解码延时
NSString * const FYParameterDecoderMaxAnalyzeDuration = @"FYParameterDecoderMaxAnalyzeDuration";
// 缓冲区大小
NSString * const FYParameterDecodeerProbesize          = @"FYParameterDecodeerProbesize";




////////////////////////////////////////////////////////////////////////////////

static NSString * formatTimeInterval(CGFloat seconds, BOOL isLeft)
{
    seconds = MAX(0, seconds);
    
    NSInteger s = seconds;
    NSInteger m = s / 60;
    NSInteger h = m / 60;
    
    s = s % 60;
    m = m % 60;
    
    NSMutableString *format = [(isLeft && seconds >= 0.5 ? @"-" : @"") mutableCopy];
    if (h != 0) [format appendFormat:@"%d:%0.2d", h, m];
    else        [format appendFormat:@"%d", m];
    [format appendFormat:@":%0.2d", s];
    
    return format;
}

////////////////////////////////////////////////////////////////////////////////

enum {
    
    KxMovieInfoSectionGeneral,
    KxMovieInfoSectionVideo,
    KxMovieInfoSectionAudio,
    KxMovieInfoSectionSubtitles,
    KxMovieInfoSectionMetadata,
    KxMovieInfoSectionCount,
};

enum {
    
    KxMovieInfoGeneralFormat,
    KxMovieInfoGeneralBitrate,
    KxMovieInfoGeneralCount,
};

////////////////////////////////////////////////////////////////////////////////

static NSMutableDictionary * gHistory;

#define LOCAL_MIN_BUFFERED_DURATION   0.2
#define LOCAL_MAX_BUFFERED_DURATION   0.4
#define NETWORK_MIN_BUFFERED_DURATION 2.0
#define NETWORK_MAX_BUFFERED_DURATION 4.0

@interface FYMoviePlayerController()
{
    UIView *m_parentView;// 父容器
    
    KxMovieDecoder *m_decoder;/// 解码器
    KxMovieGLView *m_glView;  /// 显示view
    UIImageView   *m_imageView;/// tianbu
    NSDictionary  *m_parameters;// 参数配置字典
    
    BOOL                m_bInterrupted;/// 是否中断解码处理
    BOOL                m_bBuffered;
    BOOL                m_disableUpdateHUD;
    
    dispatch_queue_t    m_dispatchQueue;// 异步队列
    dispatch_queue_t    m_dispatchQueueOperation;// 操作异步队列
    NSMutableArray      *m_videoFrames; // 视频帧组
    NSMutableArray      *m_audioFrames; // 音频帧组
    NSMutableArray      *m_subtitles;   // 字幕帧组
    
    CGFloat             m_bufferedDuration;
    CGFloat             m_minBufferedDuration;
    CGFloat             m_maxBufferedDuration;
    CGFloat             m_moviePosition;
    
    NSTimeInterval      m_tickCorrectionTime;
    NSTimeInterval      m_tickCorrectionPosition;
    
    NSUInteger          m_tickCounter;
    NSUInteger          m_currentAudioFramePos;// 当前音频帧位置
    
    NSData              *m_currentAudioFrame;// 当前音频帧
    
    NSString*   m_playPath;// 播放路径
    
}

@property (readwrite, strong) KxArtworkFrame *artworkFrame;

@property (readwrite) BOOL isDecoding;/// 解码中

@end



static FYMoviePlayerController *g_fyMoviePlayer = nil;// 单例

@implementation FYMoviePlayerController



#pragma mark - 继承

+ (void)initialize
{
    if (!gHistory)
        gHistory = [NSMutableDictionary dictionary];
}

#pragma mark - 接口

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

+ (id)moviePlayerWithContentPath: (NSString*)path parameters: (NSDictionary*)parameters
{
    if (!g_fyMoviePlayer) {
        id<KxAudioManager> audioManager = [KxAudioManager audioManager];
        [audioManager activateAudioSession];
        g_fyMoviePlayer = [[FYMoviePlayerController alloc] initWithContentPath: path parameters: parameters];
    }

    return g_fyMoviePlayer;
}

+ (id)moviePlayerWithContentURL: (NSURL *)url parameters: (NSDictionary*)parameters;
{
    return [FYMoviePlayerController moviePlayerWithContentPath:url.absoluteString parameters:parameters];
}

- (UIView*)view
{
    return m_glView;
}


- (BOOL)interruptDecoder
{
    return m_bInterrupted;
}

- (id)init
{
    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
    [audioManager activateAudioSession];
    
    return [self initWithContentPath:nil parameters:nil];
}

// 使用URL初始化
- (id)initWithContentURL:(NSURL *)url parameters:(NSDictionary*)parameters;
{

    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
    [audioManager activateAudioSession];
    
    return [self initWithContentPath:url.absoluteString parameters:parameters];

}

// 使用Path初始化
- (id) initWithContentPath: (NSString *) path
                parameters: (NSDictionary *) parameters
{
    // 初始化播放器
    
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:[UIApplication sharedApplication]];
        
        [self initDefaultProrperty];
        m_parameters = parameters;
        
        
        m_glView = [[KxMovieGLView alloc] init];
        m_glView.backgroundColor = [UIColor blackColor];
        if (!m_glView)  {
            m_glView = nil;
            NSLog(@"设置解码器失败");
            LoggerVideo(0, @"fallback to use RGB video frame and UIKit");
            [m_decoder setupVideoFrameFormat:KxVideoFrameFormatRGB];
            m_imageView = [[UIImageView alloc] init];
            m_imageView.backgroundColor = [UIColor blackColor];
            
        }
        UIView *frameView = [self frameView];
        frameView.contentMode = UIViewContentModeScaleAspectFit;
        frameView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
        
        
        m_dispatchQueue  = dispatch_queue_create("KxMovie", DISPATCH_QUEUE_SERIAL);
        m_videoFrames    = [NSMutableArray array];
        m_audioFrames    = [NSMutableArray array];
        m_subtitles      = [NSMutableArray array];
        
        [self setPlayPath:path];
        
        
    }
    return self;
}

- (void)play
{

    /// 播放
    if (!self.isPrepareToPlay) {
        NSLog(@"没有初始化播放视频，请先初始化播放视频");
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
    
        if (self.isPlaying) return;
        
        if (!m_decoder.validVideo &&
            !m_decoder.validAudio) {
            NSLog(@"validVideo and validAudio is empty.");
            return;
        }

        _isPlaying = YES;
        m_bInterrupted = NO;
        m_disableUpdateHUD = NO;
        m_tickCorrectionTime = 0;
        m_tickCounter = 0;
        
        
        [self asyncDecodeFrames];
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self tick];
        });
        
        if (m_decoder.validAudio)
            [self enableAudio:YES];
        [self setPlaybackState:FYMoviePlaybackStatePlaying];
        
        // 重刷界面
        m_glView.contentMode = m_glView.contentMode;
        LoggerStream(1, @"play movie");
    });




}

- (void) pause
{
    /// 暂停
    if (!self.isPrepareToPlay) {
        NSLog(@"没有初始化播放视频，请先初始化播放视频");
    }
    
    if (!self.isPlaying) return;
    
    _isPlaying = NO;
//    m_bInterrupted = YES;
    [self enableAudio:NO];
    
    [self setPlaybackState:FYMoviePlaybackStatePaused];
    LoggerStream(1, @"pause movie");
}


- (void)stop
{
    // 停止
    
    if (!self.isPrepareToPlay) {
        NSLog(@"没有初始化播放视频，请先初始化播放视频");
    }
    
    if (!self.isPlaying) return;

    _isPlaying = NO;
    m_bInterrupted = YES;
    [self enableAudio:NO];

    [self setPlaybackState:FYMoviePlaybackStateStopped];
    LoggerStream(1, @"stop movie");
    [self freeBufferedFrames];
    // 释放解码器
    m_decoder = nil;
    m_moviePosition = 0;
    [m_glView setDecoder:nil];
    [m_glView resetView];
    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
    [audioManager deactivateAudioSession];
}

- (NSTimeInterval)duration
{
    // 当前视频时长
    
    return (NSTimeInterval)m_decoder.duration;
}

- (NSTimeInterval)currentPlaybackTime
{
    /// 当前播放进度的位置
    
    return m_moviePosition;
}

- (void)setCurrentPlaybackTime:(NSTimeInterval)currentPlaybackTime
{
    /// 设置当前播放位置
    if (currentPlaybackTime > m_moviePosition) {
        // 往前
        [self setPlaybackState:FYMoviePlaybackStateSeekingForward];
    }else if (currentPlaybackTime < m_moviePosition){
        // 后退
        [self setPlaybackState:FYMoviePlaybackStateSeekingBackward];
        
    }
    [self postNotification:FYMoviePlayerControllerPlaybackPosDidChangeNotification];
    [self setMoviePosition:(CGFloat)currentPlaybackTime];
}

- (NSTimeInterval)initialPlaybackTime
{
    return m_decoder.startTime;
}

- (CGSize)naturalSize
{
    return CGSizeMake(m_decoder.frameWidth, m_decoder.frameHeight);
}

- (void)setContentURL:(NSURL *)contentURL
{
    /// 设置播放URL
    
    [self setContentPath:contentURL.absoluteString];
}

- (void)setContentPath:(NSString *)contentPath
{
    /// 设置播放路径
    if (!contentPath || [contentPath isEqualToString:@""]){
        NSLog(@"==== 路径为空!!");
        return;
    }
    
    [self setPlayPath:contentPath];
    
}

- (void)setScalingMode:(FYMovieScalingMode)scalingMode
{
    /// 视频显示模式
    
    switch (scalingMode) {
        case FYMovieScalingModeFill:
            [self frameView].contentMode = UIViewContentModeScaleToFill;
            break;

        case FYMovieScalingModeAspectFill:
            [self frameView].contentMode = UIViewContentModeScaleAspectFill;
            break;
        case FYMovieScalingModeAspectFit:
        case FYMovieScalingModeNone:
        default:
            [self frameView].contentMode = UIViewContentModeScaleAspectFit;
            
            break;
    }
    [self postNotification:FYMoviePlayerControllerScalingModeDidChangeNotification];
}

- (void)setParameters:(NSDictionary *)parameters
{
    /// 配置播放器参数
    
    m_parameters = parameters;
    [self configDecoder];
}


// 初始化播放视频 必须先调这个才能播放
- (void)prepareToPlay
{

    
    dispatch_async(dispatch_get_main_queue(), ^{
    
        if (m_playPath && m_playPath.length > 0) {
            
            NSError *error = nil;
            id<KxAudioManager> audioManager = [KxAudioManager audioManager];
            [audioManager deactivateAudioSession];
            
            __weak FYMoviePlayerController *weakSelf = self;
            
            m_decoder = [[KxMovieDecoder alloc] init];
            m_decoder.interruptCallback = ^BOOL(){
                
                __strong FYMoviePlayerController *strongSelf = weakSelf;
                return strongSelf ? [strongSelf interruptDecoder] : YES;
            };
            // 配置解码器
            [self configDecoder];
            
            [m_decoder openFile:m_playPath error:&error];
            
            if (!error) {
                [m_glView setDecoder:m_decoder];
                // 配置解码器
//                [self configDecoder];
                
                
                /// 发送准备播放通知
                [self postNotification:FYMoviePlayerControllerDidPrepareNotification];
                

                LoggerStream(2, @"buffered limit: %.1f - %.1f", m_minBufferedDuration, m_maxBufferedDuration);
                _isPrepareToPlay = YES;
                [self postNotification:FYMoviePlayerControllerNowPlayingMovieDidChangeNotification];
                
                if (_shouldAutoPlay) {
                    [self play];
                }
            } else {
                
                if (!m_bInterrupted){
                    [self handleDecoderMovieError: error];
                    NSLog(@"打开视频地址失败");
                }
                
                
            }
            
            
        }
        
    });


}

#pragma mark - 内部

- (void)applicationWillResignActive:(NSNotification *)n
{
    /// 程序进入后台监听
    
    NSLog(@"enter background... pause");
    [self pause];
}

- (void)setPlaybackState:(FYPMoviePlaybackState)state
{
    /// 设置播放状态
    
    _playbackState = state;
    /// 发送状态变化通知
    [self postNotification:FYMoviePlayerControllerPlaybackStateDidChangeNotification];
}


- (void)postNotification:(NSString*)notificationName
{
    /// 发送通知
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self];
}


- (void) initDefaultProrperty
{
    /// 初始化默认属性
    _playbackState = FYMoviePlaybackStateStopped;
    _isPlaying = NO;
    _shouldAutoPlay = YES;
    m_dispatchQueueOperation = dispatch_queue_create("operationQueue", DISPATCH_QUEUE_SERIAL);
}

- (void)configDecoder
{
    /// 配置decoder
    
    if (m_decoder) {
        m_decoder.parameter = m_parameters;
    }
    
    if (m_decoder.isNetwork) {
        
        m_minBufferedDuration = NETWORK_MIN_BUFFERED_DURATION;
        m_maxBufferedDuration = NETWORK_MAX_BUFFERED_DURATION;
        
    } else {
        
        m_minBufferedDuration = LOCAL_MIN_BUFFERED_DURATION;
        m_maxBufferedDuration = LOCAL_MAX_BUFFERED_DURATION;
    }
    
    if (!m_decoder.validVideo)
        m_minBufferedDuration *= 10.0; // increase for audio
    
    // allow to tweak some parameters at runtime
    if (m_parameters.count) {
        
        id val;
        
        val = [m_parameters valueForKey: FYParameterMinBufferedDuration];
        if ([val isKindOfClass:[NSNumber class]])
            m_minBufferedDuration = [val floatValue];
        
        val = [m_parameters valueForKey: FYParameterMaxBufferedDuration];
        if ([val isKindOfClass:[NSNumber class]])
            m_maxBufferedDuration = [val floatValue];
        
        val = [m_parameters valueForKey: FYParameterDisableDeinterlacing];
        if ([val isKindOfClass:[NSNumber class]])
            m_decoder.disableDeinterlacing = [val boolValue];
        
        if (m_maxBufferedDuration < m_minBufferedDuration)
            m_maxBufferedDuration = m_minBufferedDuration * 2;
    }
}

- (void) setMovieDecoder: (KxMovieDecoder *) decoder
               withError: (NSError *) error
{
    LoggerStream(2, @"setMovieDecoder");
    
    if (!error && decoder) {
        
        m_decoder        = decoder;
        m_dispatchQueue  = dispatch_queue_create("KxMovie", DISPATCH_QUEUE_SERIAL);
        m_videoFrames    = [NSMutableArray array];
        m_audioFrames    = [NSMutableArray array];
        
        if (m_decoder.subtitleStreamsCount) {
            m_subtitles = [NSMutableArray array];
        }
        // 配置解码器
        
        [self configDecoder];
        LoggerStream(2, @"buffered limit: %.1f - %.1f", m_minBufferedDuration, m_maxBufferedDuration);

        [self postNotification:FYMoviePlayerControllerNowPlayingMovieDidChangeNotification];
    } else {
        
        if (!m_bInterrupted)
            [self handleDecoderMovieError: error];
        
    }
}

- (void) handleDecoderMovieError: (NSError *) error
{
    /// 处理错误信息
    
    NSDictionary *dic = [NSDictionary dictionaryWithObject:error forKey:KMP_DIC_KEY_ERROR_DESCRIPTION];
    [[NSNotificationCenter defaultCenter]postNotificationName:FYMoviePlayerControllerErrorNotification object:self userInfo:dic];
}

- (UIView*)frameView
{
    return m_glView ? m_glView : m_imageView;
}



- (void) setMoviePosition: (CGFloat) position
{
    // 设置视频播放位置
    
    BOOL playMode = self.isPlaying;
    m_disableUpdateHUD = YES;
    _isPlaying = NO;
    [self enableAudio:NO];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        
        [self updatePosition:position playMode:playMode];
    });
}

- (BOOL) decodeFrames
{
    /// 解码帧
    
    NSArray *frames = nil;
    
    if (m_decoder.validVideo || m_decoder.validAudio) {
        
        frames = [m_decoder decodeFrames:0];
    }
    
    if (frames.count) {
        return [self addFrames: frames];
    }
    return NO;
}

- (void) asyncDecodeFrames
{
    
    /// 异步解码帧
    
    if (self.isDecoding){
        return;
    }
    
    
    __weak FYMoviePlayerController *weakSelf = self;
    __weak KxMovieDecoder *weakDecoder = m_decoder;
    
    const CGFloat duration = m_decoder.isNetwork ? .0f : 0.1f;
    
    self.isDecoding = YES;
    dispatch_async(m_dispatchQueue, ^{
        

        
        {
        __strong FYMoviePlayerController *strongSelf = weakSelf;
        if (!strongSelf.isPlaying)
            return;
        }
        
        BOOL good = YES;
        while (good) {
            
            good = NO;
            
            @autoreleasepool {
                
                __strong KxMovieDecoder *decoder = weakDecoder;
                
                if (decoder && (decoder.validVideo || decoder.validAudio)) {

                    NSArray *frames = [decoder decodeFrames:duration];
                    if (frames.count) {
                        
                        __strong FYMoviePlayerController *strongSelf = weakSelf;
                        if (strongSelf)
                            good = [strongSelf addFrames:frames];
                    }///
                }
            }// end autorelease pool
        }// end while
        
        {
        __strong FYMoviePlayerController *strongSelf = weakSelf;
        if (strongSelf) strongSelf.isDecoding = NO;
        }
        
    });
}

- (BOOL) addFrames: (NSArray *)frames
{
    /// 添加播放帧
    
    
    if (m_decoder.validVideo) {
        
        @synchronized(m_videoFrames) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeVideo) {
                    [m_videoFrames addObject:frame];
                    m_bufferedDuration += frame.duration;
                }
        }
    }
    
    if (m_decoder.validAudio) {
        
        @synchronized(m_audioFrames) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeAudio) {
                    [m_audioFrames addObject:frame];
                    if (!m_decoder.validVideo)
                        m_bufferedDuration += frame.duration;
                }
        }
        
        if (!m_decoder.validVideo) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeArtwork)
                    self.artworkFrame = (KxArtworkFrame *)frame;
        }
    }
    
    if (m_decoder.validSubtitles) {
        
        @synchronized(m_subtitles) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeSubtitle) {
                    [m_subtitles addObject:frame];
                }
        }
    }
    
    NSLog(@"==== bufferduration:%f", m_bufferedDuration);
    
    return self.isPlaying && m_bufferedDuration < m_maxBufferedDuration;
}

- (void) audioCallbackFillData: (float *) outData
                     numFrames: (UInt32) numFrames
                   numChannels: (UInt32) numChannels
{
    //fillSignalF(outData,numFrames,numChannels);
    //return;
    
    if (m_bBuffered) {
        memset(outData, 0, numFrames * numChannels * sizeof(float));
        return;
    }
    
    @autoreleasepool {
        
        while (numFrames > 0) {
            
            if (!m_currentAudioFrame) {
                
                @synchronized(m_audioFrames) {
                    
                    NSUInteger count = m_audioFrames.count;
                    
                    if (count > 0) {
                        
                        KxAudioFrame *frame = m_audioFrames[0];

                        if (m_decoder.validVideo) {
                            
                            const CGFloat delta = m_moviePosition - frame.position;
                            
                            if (delta < -0.1) {
                                
                                memset(outData, 0, numFrames * numChannels * sizeof(float));
                                break; // silence and exit
                            }
                            
                            [m_audioFrames removeObjectAtIndex:0];
                            
                            if (delta > 0.1 && count > 1) {
                                continue;
                            }
                            
                        } else {
                            
                            [m_audioFrames removeObjectAtIndex:0];
                            m_moviePosition = frame.position;
                            m_bufferedDuration -= frame.duration;
                        }
                        
                        m_currentAudioFramePos = 0;
                        m_currentAudioFrame = frame.samples;
                    }
                }
            }
            
            if (m_currentAudioFrame) {
                
                const void *bytes = (Byte *)m_currentAudioFrame.bytes + m_currentAudioFramePos;
                const NSUInteger bytesLeft = (m_currentAudioFrame.length - m_currentAudioFramePos);
                const NSUInteger frameSizeOf = numChannels * sizeof(float);
                const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
                const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
                
                memcpy(outData, bytes, bytesToCopy);
                numFrames -= framesToCopy;
                outData += framesToCopy * numChannels;
                
                if (bytesToCopy < bytesLeft)
                    m_currentAudioFramePos += bytesToCopy;
                else
                    m_currentAudioFrame = nil;
                
            } else {
                
                memset(outData, 0, numFrames * numChannels * sizeof(float));
                break;
            }
        }
    }
}

- (void) enableAudio: (BOOL) on
{
    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
    
    if (on && m_decoder.validAudio) {
        
        audioManager.outputBlock = ^(float *outData, UInt32 numFrames, UInt32 numChannels) {
            
            [self audioCallbackFillData: outData numFrames:numFrames numChannels:numChannels];
        };
        
        [audioManager play];
        
        LoggerAudio(2, @"audio device smr: %d fmt: %d chn: %d",
                    (int)audioManager.samplingRate,
                    (int)audioManager.numBytesPerSample,
                    (int)audioManager.numOutputChannels);
        
    } else {
        
        [audioManager pause];
        audioManager.outputBlock = nil;
    }
}

- (void) tick
{
    /// 定时取帧
    
    if (m_bBuffered && ((m_bufferedDuration > m_minBufferedDuration) || m_decoder.isEOF)) {
        NSLog(@"缓冲结束");
        m_tickCorrectionTime = 0;
        m_bBuffered = NO;
        [self setPlaybackState:FYMoviePlaybackStatePlaying];
        [self postNotification:FYMoviePlayerControllerDidFinishedCachingNotification];

    }
    
    CGFloat interval = 0;
    if (!m_bBuffered)
        interval = [self presentFrame];
    
    if (self.isPlaying) {
        
        const NSUInteger leftFrames =
        (m_decoder.validVideo ? m_videoFrames.count : 0) +
        (m_decoder.validAudio ? m_audioFrames.count : 0);
        
        if (0 == leftFrames) {
//        if (m_videoFrames.count == 0 || m_audioFrames.count == 0) {
            
            /// 视频解码结束
            if (m_decoder.isEOF) {

                // 结束通知
                [self postNotification:FYMoviePlayerControllerPlaybackDidFinishNotification];
                [self updateHUD];
                [self pause];
                return;
            }
            
            if (m_minBufferedDuration > 0 && !m_bBuffered) {
                NSLog(@"开始缓冲");
                m_bBuffered = YES;
                // 网络加载
                // 播放中断
                [self setPlaybackState:FYMoviePlaybackStateInterrupted];
                [self postNotification:FYMoviePlayerControllerStartCachingNotification];
                
            }
        }
        
        if (!leftFrames ||
            !(m_bufferedDuration > m_minBufferedDuration)) {
            
            [self asyncDecodeFrames];
        }
        
        const NSTimeInterval correction = [self tickCorrection];
        const NSTimeInterval time = MAX(interval + correction, 0.01);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self tick];
        });
    }
    
    if ((m_tickCounter++ % 3) == 0) {
        [self updateHUD];
    }
}

- (CGFloat) tickCorrection
{
    ///
    
    if (m_bBuffered)
        return 0;
    
    const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    if (!m_tickCorrectionTime) {
        
        m_tickCorrectionTime = now;
        m_tickCorrectionPosition = m_moviePosition;
        return 0;
    }
    
    NSTimeInterval dPosition = m_moviePosition - m_tickCorrectionPosition;
    NSTimeInterval dTime = now - m_tickCorrectionTime;
    NSTimeInterval correction = dPosition - dTime;

    if (correction > 1.f || correction < -1.f) {
        
        LoggerStream(1, @"tick correction reset %.2f", correction);
        correction = 0;
        m_tickCorrectionTime = 0;
//        [self pause];
    }
    
    return correction;
}

- (void) updateHUD
{
    if (m_disableUpdateHUD) {
        return;
    }
    // 更新播放进度
    
//    const CGFloat duration = m_decoder.duration;
//    const CGFloat position = m_moviePosition - m_decoder.startTime;
//    

//    NSLog(@"======= 播放进度:duration:%f, position:%f", duration, position);
    [self postNotification:FYMoviePlayerControllerPlaybackPosDidChangeNotification];

}

- (void) setMoviePositionFromDecoder
{
    // 从解码器中设置视频位置
    
    m_moviePosition = m_decoder.position;
}

- (void) setDecoderPosition: (CGFloat) position
{
    // 设置解码器的视频播放位置
    
    m_decoder.position = position;
}

- (void) updatePosition: (CGFloat) position
               playMode: (BOOL) playMode
{
    /// 更新播放位置
    
    
    [self freeBufferedFrames];
    
    position = MIN(m_decoder.duration - 1, MAX(0, position));
    
    __weak FYMoviePlayerController *weakSelf = self;
    
    dispatch_async(m_dispatchQueue, ^{
        
        if (playMode) {
            
            {
            __strong FYMoviePlayerController *strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf setDecoderPosition: position];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                __strong FYMoviePlayerController *strongSelf = weakSelf;
                if (strongSelf) {
                    [strongSelf setMoviePositionFromDecoder];
                    [strongSelf play];
                }
            });
            
        } else {
            
            {
            __strong FYMoviePlayerController *strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf setDecoderPosition: position];
            [strongSelf decodeFrames];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                __strong FYMoviePlayerController *strongSelf = weakSelf;
                if (strongSelf) {
                    m_disableUpdateHUD = NO;
                    [strongSelf setMoviePositionFromDecoder];
                    [strongSelf presentFrame];
                    [strongSelf updateHUD];
                }
            });
        }
    });
}

- (void) freeBufferedFrames
{
    /// 释放缓冲帧
    
    @synchronized(m_videoFrames) {
        [m_videoFrames removeAllObjects];
    }
    
    @synchronized(m_audioFrames) {
        
        [m_audioFrames removeAllObjects];
        m_currentAudioFrame = nil;
    }
    
    if (m_subtitles) {
        @synchronized(m_subtitles) {
            [m_subtitles removeAllObjects];
        }
    }
    
    m_bufferedDuration = 0;
    m_currentAudioFramePos = 0;
    m_currentAudioFrame = nil;
}

- (CGFloat) presentFrame
{
    CGFloat interval = 0;
    
    if (m_decoder.validVideo) {
        
        KxVideoFrame *frame;
        
        @synchronized(m_videoFrames) {
            
            if (m_videoFrames.count > 0) {
                
                frame = m_videoFrames[0];
                [m_videoFrames removeObjectAtIndex:0];
                m_bufferedDuration -= frame.duration;
            }
        }
        
        if (frame)
            interval = [self presentVideoFrame:frame];
        
    } else if (m_decoder.validAudio) {
        
        //interval = _bufferedDuration * 0.5;
        
        if (self.artworkFrame) {
            
            m_imageView.image = [self.artworkFrame asImage];
            self.artworkFrame = nil;
        }
    }
    
    if (m_decoder.validSubtitles)
        [self presentSubtitles];

    return interval;
}

- (void) presentSubtitles
{
    /// 显示字幕
    
    NSArray *actual, *outdated;
    
    if ([self subtitleForPosition:m_moviePosition
                           actual:&actual
                         outdated:&outdated]){
        
        if (outdated.count) {
            @synchronized(m_subtitles) {
                [m_subtitles removeObjectsInArray:outdated];
            }
        }
        
        if (actual.count) {
            
            NSMutableString *ms = [NSMutableString string];
            for (KxSubtitleFrame *subtitle in actual.reverseObjectEnumerator) {
                if (ms.length) [ms appendString:@"\n"];
                [ms appendString:subtitle.text];
            }
            
//            if (![_subtitlesLabel.text isEqualToString:ms]) {
//                
//                CGSize viewSize = self.view.bounds.size;
//                CGSize size = [ms sizeWithFont:_subtitlesLabel.font
//                             constrainedToSize:CGSizeMake(viewSize.width, viewSize.height * 0.5)
//                                 lineBreakMode:NSLineBreakByTruncatingTail];
//                m_subtitlesLabel.text = ms;
//                m_subtitlesLabel.frame = CGRectMake(0, viewSize.height - size.height - 10,
//                                                   viewSize.width, size.height);
//                m_subtitlesLabel.hidden = NO;
//            }
            
        } else {
//            
//            m_subtitlesLabel.text = nil;
//            m_subtitlesLabel.hidden = YES;
        }
    }
}

- (BOOL) subtitleForPosition: (CGFloat) position
                      actual: (NSArray **) pActual
                    outdated: (NSArray **) pOutdated
{
    if (!m_subtitles.count)
        return NO;
    
    NSMutableArray *actual = nil;
    NSMutableArray *outdated = nil;
    
    for (KxSubtitleFrame *subtitle in m_subtitles) {
        
        if (position < subtitle.position) {
            
            break; // assume what subtitles sorted by position
            
        } else if (position >= (subtitle.position + subtitle.duration)) {
            
            if (pOutdated) {
                if (!outdated)
                    outdated = [NSMutableArray array];
                [outdated addObject:subtitle];
            }
            
        } else {
            
            if (pActual) {
                if (!actual)
                    actual = [NSMutableArray array];
                [actual addObject:subtitle];
            }
        }
    }
    
    if (pActual) *pActual = actual;
    if (pOutdated) *pOutdated = outdated;
    
    return actual.count || outdated.count;
}

- (CGFloat) presentVideoFrame: (KxVideoFrame *) frame
{
    /// 显示视频帧
    
    if (m_glView) {
        [m_glView render:frame];
        
    } else {
        
        KxVideoFrameRGB *rgbFrame = (KxVideoFrameRGB *)frame;
        m_imageView.image = [rgbFrame asImage];
        NSLog(@"显示view不存在");
    }
    
    m_moviePosition = frame.position;
    
    return frame.duration;
}

- (void) setPlayPath:(NSString*)path
{
    NSString *temp = path;
    // 处理rtmp,rtsp直播流地址
    if ([path hasPrefix:@"rtmp"] || [path hasPrefix:@"rtsp"]) {
        temp = [NSString stringWithFormat:@"%@ live=1", path];
    }
    
    m_playPath = temp;
    
    _isPrepareToPlay = NO;
    
    NSLog(@"need to prepareToPlay.cur path:%@", path);
    
}

@end
