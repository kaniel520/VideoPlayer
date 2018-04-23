//
//  FYMoviePlayerController.h
//  KMoviePlaerExamper
//
//  Created by Mac on 14-7-18.
//  Copyright (c) 2014年 FengYingOnline. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


#ifdef __cplusplus
#define FYMP_EXTERN extern "C" __attribute__((visibility ("default")))
#else
#define FYMP_EXTERN     extern __attribute__((visibility ("default")))
#endif

// -----------------------------------------------------------------------------
// FYMoviePlayerController 通知

// 当缩放比例发生改变时发送此通知
FYMP_EXTERN NSString *const FYMoviePlayerControllerScalingModeDidChangeNotification;

// 当视频播放准备完毕时发送此通知
FYMP_EXTERN NSString *const FYMoviePlayerControllerDidPrepareNotification;

// 当视频播放结束或者用户退出时发送此通知
FYMP_EXTERN NSString *const FYMoviePlayerControllerPlaybackDidFinishNotification;

// 当播放状态发生改变时发送此通知
FYMP_EXTERN NSString *const FYMoviePlayerControllerPlaybackStateDidChangeNotification;

// 当视频开始网络缓冲时发送此通知
FYMP_EXTERN NSString *const FYMoviePlayerControllerStartCachingNotification;

// 当视频结束网络缓冲时发送此通知
FYMP_EXTERN NSString *const FYMoviePlayerControllerDidFinishedCachingNotification;

// 当前视频播放发生改变时发送此通知
FYMP_EXTERN NSString *const FYMoviePlayerControllerNowPlayingMovieDidChangeNotification;

// 当前视频播放位置发生改变发送此通知
FYMP_EXTERN NSString *const FYMoviePlayerControllerPlaybackPosDidChangeNotification;

// 各种错误通知标示符
FYMP_EXTERN NSString * const FYMoviePlayerControllerErrorNotification;


// 通知内部字典的信息key

/// 错误描述 获取对象为: NSError
FYMP_EXTERN NSString * const KMP_DIC_KEY_ERROR_DESCRIPTION;


/// 参数配置信息key
FYMP_EXTERN NSString * const FYParameterMinBufferedDuration;// 最小缓冲区时长
FYMP_EXTERN NSString * const FYParameterMaxBufferedDuration;// 最大缓冲区时长
FYMP_EXTERN NSString * const FYParameterDisableDeinterlacing;

// 配置解码部分参数
// 解码延时
FYMP_EXTERN NSString * const FYParameterDecoderMaxAnalyzeDuration;
// 缓冲区大小
FYMP_EXTERN NSString * const FYParameterDecodeerProbesize;

// 视频展示模式
enum {
    FYMovieScalingModeNone,       // No scaling
    FYMovieScalingModeAspectFit,  // Uniform scale until one dimension fits
    FYMovieScalingModeAspectFill, // Uniform scale until the movie fills the visible bounds. One dimension may have clipped contents
    FYMovieScalingModeFill        // Non-uniform scale. Both render dimensions will exactly match the visible bounds
};
typedef NSInteger FYMovieScalingMode;

// 播放状态
enum {
    FYMoviePlaybackStateStopped = 0,// 停止
    FYMoviePlaybackStatePlaying,    // 播放中
    FYMoviePlaybackStatePaused,     // 暂停
    FYMoviePlaybackStateInterrupted,// 中断包括 网络中断或者播放器内部中断
    FYMoviePlaybackStateSeekingForward,// 前进
    FYMoviePlaybackStateSeekingBackward// 后退
};
typedef NSInteger FYPMoviePlaybackState;

// ================================================================================================================================



//
// 风影播放器
//
@interface FYMoviePlayerController : NSObject

// 获取播放器实例
/*
 path:播放文件路径
 parameters:配置的播放器参数字典，参数配置信息key，可以配置最小缓冲时长，和最大缓冲时长等
 */
+ (id)moviePlayerWithContentPath: (NSString*)path parameters: (NSDictionary*)parameters;

// 获取播放器实例
+ (id)moviePlayerWithContentURL: (NSURL *)url parameters: (NSDictionary*)parameters;


// 使用URL初始化
- (id)initWithContentURL:(NSURL *)url parameters:(NSDictionary*)parameters;

// 使用Path初始化
- (id)initWithContentPath:(NSString *)path parameters:(NSDictionary*)parameters;

// 配置播放器参数
- (void)setParameters:(NSDictionary*)parameters;

- (UIView*)frameView;

// 播放
- (void)play;

// 暂停
- (void)pause;

// 停止
- (void)stop;

// 初始化播放视频 必须先调这个才能播放
- (void)prepareToPlay;

// 显示的view
@property(nonatomic, readonly)UIView *view;

// 播放的URL
@property(nonatomic, copy)NSURL *contentURL;

// 播放的路径
@property(nonatomic, copy)NSString *contentPath;

// 返回当前播放状态
@property(nonatomic, readonly)FYPMoviePlaybackState playbackState;

// 是否自动播放影片，默认为 YES
@property(nonatomic)BOOL shouldAutoPlay;

// 是否在播放
@property(nonatomic, readonly)BOOL isPlaying;

// 是否准备好播放
@property(nonatomic, readonly)BOOL isPrepareToPlay;

// 决定播放内容如何展示在view上面，默认为 FYMovieScalingModeAspectFit
@property(nonatomic)FYMovieScalingMode scalingMode;

// 视频播放时长 如果未知则为 0.0.
@property(nonatomic, readonly) NSTimeInterval duration;

// 当前视频可播放长度
@property(nonatomic, readonly) NSTimeInterval playableDuration;

// 当前视频播放位置 如果改变该值，播放位置将按照改变值改变
@property(nonatomic)NSTimeInterval currentPlaybackTime;

// 视频原始尺寸 如果未知则为 CGSizeZero
@property(nonatomic, readonly) CGSize naturalSize;

// 起始播放时间，默认为0.0 表示从视频开始位置进行播放
@property(nonatomic) NSTimeInterval initialPlaybackTime;

@end
