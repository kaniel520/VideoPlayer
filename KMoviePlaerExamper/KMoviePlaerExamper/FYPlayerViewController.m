//
//  FYPlayerViewController.m
//  KMoviePlaerExamper
//
//  Created by Mac on 14-7-21.
//  Copyright (c) 2014年 FengYingOnline. All rights reserved.
//

#import "FYPlayerViewController.h"

#import "FYMoviePlayerController.h"

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

@interface FYPlayerViewController ()
{
    FYMoviePlayerController *m_player;
    UILabel *m_labelTimeShow;
    
    UIView              *_topHUD;
    UIToolbar           *_topBar;
    UIToolbar           *_bottomBar;
    UISlider            *_progressSlider;
    UIButton            *_doneButton;
    UILabel             *_progressLabel;
    UILabel             *_leftLabel;
    
    
    UIBarButtonItem     *_playBtn;
    UIBarButtonItem     *_pauseBtn;
    UIBarButtonItem     *_rewindBtn;
    UIBarButtonItem     *_fforwardBtn;
    UIBarButtonItem     *_spaceItem;
    UIBarButtonItem     *_fixedSpaceItem;
    
    UIActivityIndicatorView *_activityIndicatorView;
    
    BOOL                _hiddenHUD;
    
    
    UITapGestureRecognizer *_tapGestureRecognizer;
    UITapGestureRecognizer *_doubleTapGestureRecognizer;
    UIPanGestureRecognizer *_panGestureRecognizer;
}

@end

@implementation FYPlayerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

    self.view.backgroundColor = [UIColor grayColor];
    

    
    //m_player = [[FYMoviePlayerController alloc]initWithContentPath:self.playUrl];
    m_player = [[FYMoviePlayerController alloc]init];
    
    // increase buffering for .wmv, it solves problem with delaying audio frames
//    if ([path.pathExtension isEqualToString:@"wmv"])
//        parameters[KxMovieParameterMinBufferedDuration] = @(5.0);
//
    
    
    


    
    [m_player.view setFrame:self.view.bounds];
    

    [self.view addSubview:m_player.view];
    
    

    
    //[m_player play];
    
//    m_labelTimeShow = [[UILabel alloc] initWithFrame:CGRectMake(50, 250, 200, 30)];
//    m_labelTimeShow.textColor = [UIColor blueColor];
//    [self.view addSubview:m_labelTimeShow];
    
    /*
     // 当缩放比例发生改变时发送此通知
     FYMP_EXTERN NSString *const FYMoviePlayerControllerScalingModeDidChangeNotification;
     
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
     */
    
    /// 监听播放进度
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(playPosChanged:) name:FYMoviePlayerControllerPlaybackPosDidChangeNotification object:nil];
    /// 监听开始新播放一个地址
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(playMovieDidChanged:) name:FYMoviePlayerControllerNowPlayingMovieDidChangeNotification object:nil];
    
    // 网络缓冲开始
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(playMovieStartCaching:) name:FYMoviePlayerControllerStartCachingNotification object:nil];
    
    // 网络缓冲结束
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(playMovieDidFinishedCaching:) name:FYMoviePlayerControllerDidFinishedCachingNotification object:nil];
    
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(playMovieStateChanged:) name:FYMoviePlayerControllerPlaybackStateDidChangeNotification object:nil];
//    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(playMovieDidChanged:) name:FYMoviePlayerControllerNowPlayingMovieDidChangeNotification object:nil];
//    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(playMovieDidChanged:) name:FYMoviePlayerControllerNowPlayingMovieDidChangeNotification object:nil];
//    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(playMovieDidChanged:) name:FYMoviePlayerControllerNowPlayingMovieDidChangeNotification object:nil];
    
    
    
    [self initPlayControllerViews];
    [self setupUserInteraction];
    
    _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleWhiteLarge];
    _activityIndicatorView.center = self.view.center;
    _activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    _activityIndicatorView.hidesWhenStopped = YES;
    
    [self.view addSubview:_activityIndicatorView];
    
    [_activityIndicatorView startAnimating];

}

- (void)viewDidAppear:(BOOL)animated
{
    
    
    [self showHUD: YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:[UIApplication sharedApplication]];
    
    NSMutableDictionary *dic = [[NSMutableDictionary alloc]init];
    //    // disable deinterlacing for iPhone, because it's complex operation can cause stuttering
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        dic[FYParameterDisableDeinterlacing] = @(NO);
    
    dic[FYParameterMaxBufferedDuration] = [NSNumber numberWithFloat:10];
    dic[FYParameterMinBufferedDuration] = [NSNumber numberWithFloat:2];
    
    [m_player setParameters:dic];
    
    m_player.contentPath = self.playUrl;
    
    m_player.initialPlaybackTime = 0;
    
    [m_player prepareToPlay];
}

- (void) setupUserInteraction
{
    UIView * view = [m_player frameView];
    view.userInteractionEnabled = YES;
    
    _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    _tapGestureRecognizer.numberOfTapsRequired = 1;
    
    _doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    _doubleTapGestureRecognizer.numberOfTapsRequired = 2;
    
    [_tapGestureRecognizer requireGestureRecognizerToFail: _doubleTapGestureRecognizer];
    
    [view addGestureRecognizer:_doubleTapGestureRecognizer];
    [view addGestureRecognizer:_tapGestureRecognizer];
    
    //    _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    //    _panGestureRecognizer.enabled = NO;
    //
    //    [view addGestureRecognizer:_panGestureRecognizer];
}

- (void) handleTap: (UITapGestureRecognizer *) sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        if (sender == _tapGestureRecognizer) {
            
            [self showHUD: _hiddenHUD];
            
        } else if (sender == _doubleTapGestureRecognizer) {
            
            UIView *frameView = [m_player frameView];
            
            if (frameView.contentMode == UIViewContentModeScaleAspectFit)
                frameView.contentMode = UIViewContentModeScaleAspectFill;
            else
                frameView.contentMode = UIViewContentModeScaleAspectFit;
            
        }
    }
}

- (void) handlePan: (UIPanGestureRecognizer *) sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        const CGPoint vt = [sender velocityInView:self.view];
        const CGPoint pt = [sender translationInView:self.view];
        const CGFloat sp = MAX(0.1, log10(fabsf(vt.x)) - 1.0);
        const CGFloat sc = fabsf(pt.x) * 0.33 * sp;
        if (sc > 10) {
            
            const CGFloat ff = pt.x > 0 ? 1.0 : -1.0;
//            [self setMoviePosition: _moviePosition + ff * MIN(sc, 600.0)];
            
            m_player.currentPlaybackTime += ff * MIN(sc, 600.0);
        }
        //LoggerStream(2, @"pan %.2f %.2f %.2f sec", pt.x, vt.x, sc);
    }
}



- (void) applicationWillResignActive: (NSNotification *)notification
{
    /// 程序进入背景˝©©˝˝
    
    [self showHUD:YES];
    [m_player pause];
    
    NSLog(@"applicationWillResignActive");
}

- (BOOL)prefersStatusBarHidden
{
    return NO;
}

- (void) showHUD: (BOOL) show
{
    _hiddenHUD = !show;
    _panGestureRecognizer.enabled = _hiddenHUD;
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:_hiddenHUD];
    
    [UIView animateWithDuration:0.2
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionNone
                     animations:^{
                         
                         CGFloat alpha = _hiddenHUD ? 0 : 1;
                         _topBar.alpha = alpha;
                         _topHUD.alpha = alpha;
                         _bottomBar.alpha = alpha;
                     }
                     completion:nil];
    
}

- (void)initPlayControllerViews
{
    CGRect bounds = self.view.bounds;
    
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    
    CGFloat topH = 50;
    CGFloat botH = 50;
    
    _topHUD    = [[UIView alloc] initWithFrame:CGRectMake(0,0,0,0)];
    
    _topBar    = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, width, topH)];
    _bottomBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, height-botH, width, botH)];
    _bottomBar.tintColor = [UIColor blackColor];
    
    _topHUD.frame = CGRectMake(0,0,width,_topBar.frame.size.height);
    
    _topHUD.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _bottomBar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    
    [self.view addSubview:_topBar];
    [self.view addSubview:_topHUD];
    [self.view addSubview:_bottomBar];
    
    // top hud
    
    _doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _doneButton.frame = CGRectMake(0, 1, 50, topH);
    _doneButton.backgroundColor = [UIColor clearColor];
    //    _doneButton.backgroundColor = [UIColor redColor];
    [_doneButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_doneButton setTitle:NSLocalizedString(@"返回", nil) forState:UIControlStateNormal];
    _doneButton.titleLabel.font = [UIFont systemFontOfSize:18];
    _doneButton.showsTouchWhenHighlighted = YES;
    [_doneButton addTarget:self action:@selector(doneDidTouch:)
          forControlEvents:UIControlEventTouchUpInside];
    
    _progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(46, 1, 50, topH)];
    _progressLabel.backgroundColor = [UIColor clearColor];
    _progressLabel.opaque = NO;
    _progressLabel.adjustsFontSizeToFitWidth = NO;
    _progressLabel.textAlignment = NSTextAlignmentRight;
    _progressLabel.textColor = [UIColor blackColor];
    _progressLabel.text = @"";
    _progressLabel.font = [UIFont systemFontOfSize:12];
    
    _progressSlider = [[UISlider alloc] initWithFrame:CGRectMake(100, 2, width-197, topH)];
    _progressSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _progressSlider.continuous = NO;
    _progressSlider.value = 0;
    
    
    _leftLabel = [[UILabel alloc] initWithFrame:CGRectMake(width-92, 1, 60, topH)];
    _leftLabel.backgroundColor = [UIColor clearColor];
    _leftLabel.opaque = NO;
    _leftLabel.adjustsFontSizeToFitWidth = NO;
    _leftLabel.textAlignment = NSTextAlignmentLeft;
    _leftLabel.textColor = [UIColor blackColor];
    _leftLabel.text = @"";
    _leftLabel.font = [UIFont systemFontOfSize:12];
    _leftLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    
    
    [_topHUD addSubview:_doneButton];
    [_topHUD addSubview:_progressLabel];
    [_topHUD addSubview:_progressSlider];
    [_topHUD addSubview:_leftLabel];
    
    // bottom hud
    
    _spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                               target:nil
                                                               action:nil];
    
    _fixedSpaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                    target:nil
                                                                    action:nil];
    _fixedSpaceItem.width = 30;
    
    _rewindBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRewind
                                                               target:self
                                                               action:@selector(rewindDidTouch:)];
    
    _playBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                                                             target:self
                                                             action:@selector(playDidTouch:)];
    _playBtn.width = 50;
    
    _pauseBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause
                                                              target:self
                                                              action:@selector(playDidTouch:)];
    _pauseBtn.width = 50;
    
    _fforwardBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFastForward
                                                                 target:self
                                                                 action:@selector(forwardDidTouch:)];
    
    
    [self updateBottomBar];
}

- (void) updateBottomBar
{
    UIBarButtonItem *playPauseBtn = m_player.isPlaying ? _pauseBtn : _playBtn;
    [_bottomBar setItems:@[_spaceItem, _rewindBtn, _fixedSpaceItem, playPauseBtn,
                           _fixedSpaceItem, _fforwardBtn, _spaceItem] animated:NO];
}

- (void) playDidTouch: (id) sender
{
    if (m_player.isPlaying)
        [m_player stop];
    else{
        [m_player prepareToPlay];
//        [m_player play];
    }
}

- (void) forwardDidTouch: (id) sender
{
    m_player.currentPlaybackTime += 10;
}

- (void) rewindDidTouch: (id) sender
{
    m_player.currentPlaybackTime -= 10;
}

- (void) progressDidChange: (id) sender
{
    NSAssert(m_player.duration != MAXFLOAT, @"bugcheck");
    UISlider *slider = sender;
    m_player.currentPlaybackTime = slider.value * m_player.duration;
}


- (void)doneDidTouch:(id)sender
{
    [m_player stop];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)playPosChanged:(NSNotification*)n
{
//    m_labelTimeShow.text = [NSString stringWithFormat:@"cur:%d, duration:%f", (int)m_player.currentPlaybackTime, m_player.duration];
    const CGFloat duration = m_player.duration;
    const CGFloat position = m_player.currentPlaybackTime - m_player.initialPlaybackTime;
    
    if (_progressSlider.state == UIControlStateNormal){
        _progressSlider.value = position / duration;
    _progressLabel.text = formatTimeInterval(position, NO);
    }
    
    if (m_player.duration != MAXFLOAT)
        _leftLabel.text = formatTimeInterval(duration - position, YES);
}

- (void)playMovieDidChanged:(NSNotification*)n
{
    if (m_player.duration == MAXFLOAT) {
        
        _leftLabel.text = @"\u221E"; // infinity
        _leftLabel.font = [UIFont systemFontOfSize:14];
        
        CGRect frame;
        
        frame = _leftLabel.frame;
        frame.origin.x += 40;
        frame.size.width -= 40;
        _leftLabel.frame = frame;
        
        frame =_progressSlider.frame;
        frame.size.width += 40;
        _progressSlider.frame = frame;
        
    } else {
        
        [_progressSlider addTarget:self
                            action:@selector(progressDidChange:)
                  forControlEvents:UIControlEventValueChanged];
    }

}

- (void)playMovieStartCaching:(NSNotification *)n
{
    [_activityIndicatorView startAnimating];
}

- (void)playMovieDidFinishedCaching:(NSNotification *)n
{
    [_activityIndicatorView stopAnimating];
}

- (void)playMovieStateChanged:(NSNotification *)n
{
    
//    NSLog(@"播放状态发生变化，，，，");
    switch (m_player.playbackState) {
        case FYMoviePlaybackStatePlaying:
        {
            [_activityIndicatorView stopAnimating];
        
        }
            break;
            
        default:
            
            break;
    }
    [self updateBottomBar];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
    NSLog(@"内存警告。。。。");
}

@end
