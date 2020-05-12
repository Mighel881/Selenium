#import "Tweak.h"
#import "AXNManager.h"
#import "CustomUIStepper.h"

BOOL dpkgInvalid = NO;
BOOL initialized = NO;
BOOL enabled;
BOOL vertical;
BOOL badgesEnabled;
BOOL badgesShowBackground;
BOOL hapticFeedback;
BOOL darkMode;
BOOL fadeEntireCell;
NSInteger sortingMode;
NSInteger selectionStyle;
NSInteger style;
NSInteger showByDefault;
NSInteger alignment;
NSInteger verticalPosition;
CGFloat spacing;

NSDictionary *prefs = nil;

void updateViewConfiguration() {
    if (initialized && [AXNManager sharedInstance].view) {
        [AXNManager sharedInstance].view.hapticFeedback = hapticFeedback;
        [AXNManager sharedInstance].view.badgesEnabled = badgesEnabled;
        [AXNManager sharedInstance].view.badgesShowBackground = badgesShowBackground;
        [AXNManager sharedInstance].view.selectionStyle = selectionStyle;
        [AXNManager sharedInstance].view.sortingMode = sortingMode;
        [AXNManager sharedInstance].view.style = style;
        [AXNManager sharedInstance].view.darkMode = darkMode;
        [AXNManager sharedInstance].view.showByDefault = showByDefault;
        [AXNManager sharedInstance].view.spacing = spacing;
        [AXNManager sharedInstance].view.alignment = alignment;
    }
}

%group Axon

#pragma mark Legibility color

%hook SBFLockScreenDateView

-(id)initWithFrame:(CGRect)arg1 {
    %orig;
    if (self.legibilitySettings && self.legibilitySettings.primaryColor) {
        [AXNManager sharedInstance].fallbackColor = [self.legibilitySettings.primaryColor copy];
    }
    return self;
}

-(void)setLegibilitySettings:(_UILegibilitySettings *)arg1 {
    %orig;
    if (self.legibilitySettings && self.legibilitySettings.primaryColor) {
        [AXNManager sharedInstance].fallbackColor = [self.legibilitySettings.primaryColor copy];
    }
}

%end

#pragma mark Store dispatcher for future use

%hook SBNCNotificationDispatcher

-(id)init {
    %orig;
    [AXNManager sharedInstance].dispatcher = self.dispatcher;
    return self;
}

-(void)setDispatcher:(NCNotificationDispatcher *)arg1 {
    %orig;
    [AXNManager sharedInstance].dispatcher = arg1;
}

%end

#pragma mark Inject the Axon view into NC

#pragma mark disabled

/*%hook SBDashBoardNotificationAdjunctListViewController

%property (nonatomic, retain) AXNView *axnView;


-(BOOL)hasContent {
    return YES;
}

%end*/

#pragma mark disabled

// iOS13 Support
/*%hook CSNotificationAdjunctListViewController
%property (nonatomic, retain) AXNView *axnView;
%end*/

#pragma mark Notification management

%hook NCNotificationCombinedListViewController

%property (nonatomic,assign) BOOL axnAllowChanges;

/* Store this object for future use. */

-(id)init {
    %orig;
    [AXNManager sharedInstance].clvc = self;
    self.axnAllowChanges = NO;
    return self;
}

/* Replace notification management functions with our logic. */

-(bool)insertNotificationRequest:(NCNotificationRequest *)req forCoalescedNotification:(id)arg2 {
    if (self.axnAllowChanges) return %orig;     // This condition is true when Axon is updating filtered notifications for display.
    [[AXNManager sharedInstance] insertNotificationRequest:req];
    [[AXNManager sharedInstance].view refresh];

    if (req.bulletin.sectionID) {
        NSString *bundleIdentifier = req.bulletin.sectionID;
        if ([bundleIdentifier isEqualToString:[AXNManager sharedInstance].view.selectedBundleIdentifier]) %orig;
    }

    if (![AXNManager sharedInstance].view.selectedBundleIdentifier && showByDefault == 1) {
        [[AXNManager sharedInstance].view reset];
    }

    return YES;
}

-(bool)removeNotificationRequest:(NCNotificationRequest *)req forCoalescedNotification:(id)arg2 {
    if (self.axnAllowChanges) return %orig;     // This condition is true when Axon is updating filtered notifications for display.

    NSString *identifier = [[req notificationIdentifier] copy];

    [[AXNManager sharedInstance] removeNotificationRequest:req];
    [[AXNManager sharedInstance].view refresh];

    if (req.bulletin.sectionID) {
        NSString *bundleIdentifier = req.bulletin.sectionID;
        if ([bundleIdentifier isEqualToString:[AXNManager sharedInstance].view.selectedBundleIdentifier]) %orig;
    }

    if ([AXNManager sharedInstance].view.showingLatestRequest && identifier &&
    [[[AXNManager sharedInstance].latestRequest notificationIdentifier] isEqualToString:identifier]) {
        %orig;
    }

    return YES;
}

-(bool)modifyNotificationRequest:(NCNotificationRequest *)req forCoalescedNotification:(id)arg2 {
    if (self.axnAllowChanges) return %orig;     // This condition is true when Axon is updating filtered notifications for display.

    NSString *identifier = [[req notificationIdentifier] copy];

    [[AXNManager sharedInstance] modifyNotificationRequest:req];
    [[AXNManager sharedInstance].view refresh];

    if (req.bulletin.sectionID) {
        NSString *bundleIdentifier = req.bulletin.sectionID;
        if ([bundleIdentifier isEqualToString:[AXNManager sharedInstance].view.selectedBundleIdentifier]) %orig;
    }

    if ([AXNManager sharedInstance].view.showingLatestRequest && identifier &&
    [[[AXNManager sharedInstance].latestRequest notificationIdentifier] isEqualToString:identifier]) {
        %orig;
    }

    return YES;
}

-(bool)hasContent {
    if ([AXNManager sharedInstance].view.list && [[AXNManager sharedInstance].view.list count] > 0) return YES;
    return %orig;
}

-(void)viewDidAppear:(BOOL)animated {
    %orig;
    [[AXNManager sharedInstance].view reset];
    [[AXNManager sharedInstance].view refresh];
}

/* Fix pull to clear all tweaks. */

-(void)_clearAllPriorityListNotificationRequests {
    [[AXNManager sharedInstance].dispatcher destination:nil requestsClearingNotificationRequests:[self allNotificationRequests]];
}

-(void)_clearAllNotificationRequests {
    [[AXNManager sharedInstance].dispatcher destination:nil requestsClearingNotificationRequests:[self allNotificationRequests]];
}

-(void)clearAll {
    [[AXNManager sharedInstance].dispatcher destination:nil requestsClearingNotificationRequests:[self axnNotificationRequests]];
}

/* Compatibility thing for other tweaks. */

%new
-(id)axnNotificationRequests {
    NSMutableOrderedSet *allRequests = [NSMutableOrderedSet new];
    for (NSString *key in [[AXNManager sharedInstance].notificationRequests allKeys]) {
        [allRequests addObjectsFromArray:[[AXNManager sharedInstance] requestsForBundleIdentifier:key]];
    }
    return allRequests;
}

%new
-(void)revealNotificationHistory:(BOOL)revealed {
  [self setDidPlayRevealHaptic:YES];
  [self forceNotificationHistoryRevealed:revealed animated:NO];
  [self setNotificationHistorySectionNeedsReload:YES];
  [self _reloadNotificationHistorySectionIfNecessary];
  if (!revealed && [self respondsToSelector:@selector(clearAllCoalescingControlsCells)]) [self clearAllCoalescingControlsCells];
}

%end

// iOS13 Support
@interface NCNotificationMasterList
@property(retain, nonatomic) NSMutableArray *notificationSections;
@end
@interface NCNotificationStructuredSectionList
@property (nonatomic,readonly) NSArray * allNotificationRequests;
@end
@interface NCNotificationStructuredListViewController <clvc>
@property (nonatomic,assign) BOOL axnAllowChanges;
@property (nonatomic,retain) NCNotificationMasterList * masterList;
-(void)revealNotificationHistory:(BOOL)arg1 animated:(BOOL)arg2 ;
@end
%hook NCNotificationStructuredListViewController
%property (nonatomic,assign) BOOL axnAllowChanges;
-(id)init {
    %orig;
    [AXNManager sharedInstance].clvc = self;
    self.axnAllowChanges = NO;
    return self;
}

-(bool)insertNotificationRequest:(NCNotificationRequest *)req {
    if (self.axnAllowChanges) return %orig;     // This condition is true when Axon is updating filtered notifications for display.
    [[AXNManager sharedInstance] insertNotificationRequest:req];
    [[AXNManager sharedInstance].view refresh];

    /*if (req.bulletin.sectionID) {
        NSString *bundleIdentifier = req.bulletin.sectionID;
        if ([bundleIdentifier isEqualToString:[AXNManager sharedInstance].view.selectedBundleIdentifier]) %orig;
    }*/
    %orig;

    if (![AXNManager sharedInstance].view.selectedBundleIdentifier && showByDefault == 1) {
        [[AXNManager sharedInstance].view reset];
    }

    return YES;
}

-(bool)removeNotificationRequest:(NCNotificationRequest *)req {
    if (self.axnAllowChanges) return %orig;     // This condition is true when Axon is updating filtered notifications for display.

    //NSString *identifier = [[req notificationIdentifier] copy];

    [[AXNManager sharedInstance] removeNotificationRequest:req];
    [[AXNManager sharedInstance].view refresh];

    if (req.bulletin.sectionID) {
        NSString *bundleIdentifier = req.bulletin.sectionID;
        if ([bundleIdentifier isEqualToString:[AXNManager sharedInstance].view.selectedBundleIdentifier]) %orig;
    }

    //if ([AXNManager sharedInstance].view.showingLatestRequest && identifier &&
    //[[[AXNManager sharedInstance].latestRequest notificationIdentifier] isEqualToString:identifier]) {
        %orig;
    //}

    return YES;
}

-(bool)modifyNotificationRequest:(NCNotificationRequest *)req {
    if (self.axnAllowChanges) return %orig;     // This condition is true when Axon is updating filtered notifications for display.

    //NSString *identifier = [[req notificationIdentifier] copy];

    [[AXNManager sharedInstance] modifyNotificationRequest:req];
    [[AXNManager sharedInstance].view refresh];

    if (req.bulletin.sectionID) {
        NSString *bundleIdentifier = req.bulletin.sectionID;
        if ([bundleIdentifier isEqualToString:[AXNManager sharedInstance].view.selectedBundleIdentifier]) %orig;
    }

    //if ([AXNManager sharedInstance].view.showingLatestRequest && identifier &&
    //[[[AXNManager sharedInstance].latestRequest notificationIdentifier] isEqualToString:identifier]) {
        %orig;
    //}

    return YES;
}

-(void)viewDidAppear:(BOOL)animated {
    %orig;
    [[AXNManager sharedInstance].view reset];
    [[AXNManager sharedInstance].view refresh];
}

%new
-(id)axnNotificationRequests {
    NSMutableOrderedSet *allRequests = [NSMutableOrderedSet new];
    for (NSString *key in [[AXNManager sharedInstance].notificationRequests allKeys]) {
        [allRequests addObjectsFromArray:[[AXNManager sharedInstance] requestsForBundleIdentifier:key]];
    }
    return allRequests;
}

%new
-(NSSet *)allNotificationRequests {
  NSArray *array = [NSMutableArray new];
  NCNotificationMasterList *masterList = [self masterList];
  for(NCNotificationStructuredSectionList *item in [masterList notificationSections]) {
    array = [array arrayByAddingObjectsFromArray:[item allNotificationRequests]];
  }
  return [[NSSet alloc] initWithArray:array];
}

%new
-(void)revealNotificationHistory:(BOOL)revealed {
  [self revealNotificationHistory:revealed animated:true];
}

%end
@interface SBFStaticWallpaperView : UIView 
@property (nonatomic, retain) NSString *displayedImageHashString;
@end
%hook SBFStaticWallpaperView

-(void)_setDisplayedImage:(UIImage *)image
{
    %orig;
        [[AXNManager sharedInstance] updateWallpaperColors:image];
}

%end

#pragma mark my additions

@interface NCNotificationViewController : UIViewController {
    NCNotificationRequest* _notificationRequest;
}
@property (nonatomic,retain) NCNotificationRequest * notificationRequest;                                                                                                                                                    //@synthesize notificationRequest=_notificationRequest - In the implementation block
@end

@protocol NCNotificationListViewDataSource <NSObject>
@end

@interface NCNotificationGroupList : NSObject <NCNotificationListViewDataSource>
@property (nonatomic,retain) NSMutableArray * orderedRequests;                                          //@synthesize orderedRequests=_orderedRequests - In the implementation block
@end 

@interface NCNotificationListView : UIScrollView
@property (assign,getter=isGrouped,nonatomic) BOOL grouped;                                                                          //@synthesize grouped=_grouped - In the implementation block
@property (assign,readwrite) NCNotificationGroupList<NCNotificationListViewDataSource> *dataSource;                                                 //@synthesize dataSource=_dataSource - In the implementation block
@end

@interface NCNotificationListCell : UIView {
	NCNotificationViewController* _contentViewController;
}
@property (nonatomic,retain) NCNotificationViewController * contentViewController;                          //@synthesize contentViewController=_contentViewController - In the implementation block
- (void)dateIsNow:(NSTimer *)timer ;
@end

@interface NCNotificationListCellActionButtonsView : UIView
@property (nonatomic,retain) UIStackView * buttonsStackView;
@property (nonatomic) BOOL shouldPerformDefaultAction;
- (void)swipedUp:(id)arg1;
@end

@interface UIView (FUCK)
@property (nonatomic,copy) NSString * title;                                                                             //@synthesize title=_title - In the implementation block
@end

NSString *bundleID;
NCNotificationListCell *snoozedCell;
NCNotificationRequest *argToDismiss;

NCNotificationRequest *reqToBeSnoozed;

UIView *newView;
UIButton *newButton;

%hook NCNotificationListCellActionButtonsView
-(void)layoutSubviews {
    %orig;

    // Get the options StackView array
    //NSArray<NCNotificationListCellActionButton*> *buttonsArray = self.buttonsStackView.arrangedSubviews;

    // Process only if 3 CellActionButton are present
    // Less than 3 means the left option pannel is opened or the right one is already processed
    if (self.buttonsStackView.arrangedSubviews.count == 3) {
        // Remove the Manage option 
        self.buttonsStackView.arrangedSubviews[1].title = @"Snooze";
        [self.buttonsStackView.arrangedSubviews[1] removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents]; 
        [self.buttonsStackView.arrangedSubviews[1] addTarget:self action:@selector(swipedUp:) forControlEvents:UIControlEventTouchUpInside];
    }
}

-(void)configureCellActionButtonsForNotificationRequest:(id)arg1 sectionSettings:(id)arg2 cell:(id)arg3 {
    argToDismiss = arg1;
    bundleID = argToDismiss.sectionIdentifier;
    snoozedCell = arg3;
    reqToBeSnoozed = snoozedCell.contentViewController.notificationRequest;
    NSLog(@"snoozedCell: %@", snoozedCell);
    /*if (!newView) {
        newView = [[UIView alloc] init];
        [newView setBackgroundColor:[UIColor whiteColor]];
    }
    if (newButton) {
        [newButton removeFromSuperview];
    }
    [newView setFrame:CGRectMake(0, 50, 375, 30)];
    newButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [newButton setTitle:snoozedCell.contentViewController.notificationRequest.content.message forState:UIControlStateNormal];
    [newButton setFrame:newView.bounds];
    [newView addSubview:newButton];
    [[[UIApplication sharedApplication] windows][0] addSubview:newView];*/
    %orig;
}

%new
- (void)swipedUp:(id)arg1 {
    NSDictionary *info = @{@"id": reqToBeSnoozed, @"cell": snoozedCell};
    [[NSNotificationCenter defaultCenter] postNotificationName:@"xyz.skitty.quietdown.menu" object:nil userInfo:info];
}
%end

//static double minutesLeft;
static double secondsLeft;

static NSString *configPath = @"/var/mobile/Library/QuietDown/config.plist";
static NSMutableDictionary *config;

static void processEntry(NCNotificationRequest *request, double interval, NSDate *inputDate) {
  NSString *req = [NSString stringWithFormat:@"%@", request];
  NSMutableArray *entries = [config[@"entries"] mutableCopy];
  bool add = YES;
  NSDictionary *remove = nil;
  for (NSMutableDictionary *entry in entries) {
    NSMutableArray *parts = [[entry[@"id"] componentsSeparatedByString:@";"] mutableCopy];
    [parts removeObject:parts[0]];
    NSString *combinedparts = [parts componentsJoinedByString:@";"];
    if ([req containsString:combinedparts]) {
        if (interval < 0) {
            if (interval == -1)
            entry[@"timeStamp"] = @([inputDate timeIntervalSince1970]);
            else if (interval == -2)
            entry[@"timeStamp"] = @(-2);
        } else if (interval == 0) {
            remove = entry;
        } else {
            entry[@"timeStamp"] = @([[NSDate date] timeIntervalSince1970] + interval);
        }
        add = NO;
    }
  }
  if (remove) {
    [entries removeObject:remove];
  }
  if (add) {
    NSDictionary *info;
    if (interval < 0) {
        if (interval == -1)
        info = @{@"id": req, @"timeStamp": @([inputDate timeIntervalSince1970])};
        if (interval == -2)
        info = @{@"id": req, @"timeStamp": @(-2)};
    } else if (interval != 0) {
        info = @{@"id": req, @"timeStamp": @([[NSDate date] timeIntervalSince1970] + interval)};
    }
    if (info) {
      [entries addObject:info];
    }
  }
  [config setValue:entries forKey:@"entries"];
  [config writeToFile:configPath atomically:YES];
}

@protocol NCNotificationManagementControllerSettingsDelegate <NSObject>
@optional
-(void)notificationManagementControllerDidDismissManagementView:(id)arg1;
@required
-(id)notificationManagementController:(id)arg1 sectionSettingsForSectionIdentifier:(id)arg2;
-(void)notificationManagementController:(id)arg1 setAllowsNotifications:(BOOL)arg2 forNotificationRequest:(id)arg3 withSectionIdentifier:(id)arg4;
-(void)notificationManagementController:(id)arg1 setDeliverQuietly:(BOOL)arg2 forNotificationRequest:(id)arg3 withSectionIdentifier:(id)arg4;
-(void)notificationManagementController:(id)arg1 setAllowsCriticalAlerts:(BOOL)arg2 forNotificationRequest:(id)arg3 withSectionIdentifier:(id)arg4;
@end

@protocol NCNotificationManagementController <NSObject>
@property (assign,nonatomic) id<NCNotificationManagementControllerSettingsDelegate> settingsDelegate; 
@required
-(void)setSettingsDelegate:(id<NCNotificationManagementControllerSettingsDelegate>)arg1;
-(id<NCNotificationManagementControllerSettingsDelegate>)settingsDelegate;
@end

@interface NCNotificationManagementAlertController : UIAlertController <NCNotificationManagementController> {
    	NCNotificationRequest* _request;
}
@property (nonatomic,retain) NCNotificationRequest * request;    
-(id)initWithRequest:(id)arg1 withPresentingView:(id)arg2 settingsDelegate:(id)arg3 ;                                                         //@synthesize request=_request - In the implementation block
@end

@interface NCNotificationManagementBlueButton : UIButton
+(id)buttonWithTitle:(id)arg1 ;
-(void)setBackgroundColor:(id)arg1 ;
@end

@interface NCNotificationManagementViewController : UIViewController
@property (assign,nonatomic) id<NCNotificationManagementControllerSettingsDelegate> settingsDelegate;              //@synthesize settingsDelegate=_settingsDelegate - In the implementation block
+(id)notificationManagementAlertControllerForNotificationRequest:(id)arg1 withPresentingView:(id)arg2 settingsDelegate:(id)arg3 ;
@end

@interface NCNotificationManagementViewPresenter : NSObject <NCNotificationManagementControllerSettingsDelegate>
-(void)setNotificationManagementAlertViewController:(UIAlertController *)arg1 ;
@end

@interface NCNotificationManagementView : UIView /*<MTVisualStylingProviding>*/ {
    NCNotificationManagementBlueButton* _onOffToggleButton;
	NCNotificationManagementBlueButton* _deliveryButton;
}
@property (nonatomic,readonly) NCNotificationManagementBlueButton * deliveryButton;                 //@synthesize deliveryButton=_deliveryButton - In the implementation block
@property (nonatomic,readonly) NCNotificationManagementBlueButton * onOffToggleButton;              //@synthesize onOffToggleButton=_onOffToggleButton - In the implementation block
-(id)initWithIcon:(id)arg1 title:(id)arg2 subtitle:(id)arg3 sectionSettings:(id)arg4 criticalAlert:(BOOL)arg5 ;
@end

@interface SButton : UIButton
@property (nonatomic,retain) NCNotificationRequest *request;    
@property (nonatomic,retain) NCNotificationListCell *cell;    
@property (nonatomic,retain) NSDate *pickerDate;    
@property (nonatomic,retain) UIAlertController *controllerToDismiss;    
@property (nonatomic,readwrite) BOOL grouped;    
@end

@implementation SButton
@end

@interface SpringBoard : UIApplication
@end

@interface SpringBoard ()
- (UIImage *) imageWithView:(UIView *)view;
@end

@interface NSTimer ()
- (instancetype)initWithFireDate:(NSDate *)date 
                        interval:(NSTimeInterval)interval 
                         repeats:(BOOL)repeats 
                           block:(void (^)(NSTimer *timer))block;
@end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
  %orig;
  config = [NSMutableDictionary dictionaryWithContentsOfFile:configPath];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showMuteMenu:) name:@"xyz.skitty.quietdown.menu" object:nil];
}

%new
- (void)showMuteMenu:(NSNotification *)notification {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Snooze notifications" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NCNotificationRequest *requestToProcess = notification.userInfo[@"id"];
    NCNotificationListCell *cellToCapture = notification.userInfo[@"cell"];
    NCNotificationListView *cellListView = (NCNotificationListView *)cellToCapture.superview;
    NCNotificationGroupList *groupList = cellListView.dataSource;
    NSMutableArray *reqsArray = [groupList.orderedRequests copy];

    BOOL grouped;
    if (cellListView.grouped) {
        grouped = YES;
    } else {
        grouped = NO;
    }

  [alert addAction:[UIAlertAction actionWithTitle:@"For 15 minutes" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    if(grouped){
        [[AXNManager sharedInstance] hideNotificationRequests:reqsArray];
        for (NCNotificationRequest *request in reqsArray) {
            if (![request.content.header containsString:@"Snoozed"]) {
                NSString *newTitle = [NSString stringWithFormat:@"%@ • Snoozed", request.content.header];
                [request.content setValue:newTitle forKey:@"_header"];
            }
            processEntry(request, 900, nil);
        }
        NSTimer *timerShow = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:900]
                                                      interval:nil
                                                       repeats:NO
                                                         block:(void (^)(NSTimer *timer))^{
                                                             for (NCNotificationRequest *request in reqsArray) {
                                                                processEntry(request, 0, nil);
                                                             }
                                                             [[AXNManager sharedInstance] showNotificationRequests:reqsArray];
                                                         }];
        [[NSRunLoop mainRunLoop] addTimer:timerShow forMode:NSDefaultRunLoopMode];
    } else {
        [[AXNManager sharedInstance] hideNotificationRequest:requestToProcess];
        if (![requestToProcess.content.header containsString:@"Snoozed"]) {
            NSString *newTitle = [NSString stringWithFormat:@"%@ • Snoozed", requestToProcess.content.header];
            [requestToProcess.content setValue:newTitle forKey:@"_header"];
        }
        NSTimer *timerShow = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:900]
                                                      interval:nil
                                                       repeats:NO
                                                         block:(void (^)(NSTimer *timer))^{
                                                             processEntry(requestToProcess, 0, nil);
                                                             [[AXNManager sharedInstance] showNotificationRequest:requestToProcess];
                                                         }];
        [[NSRunLoop mainRunLoop] addTimer:timerShow forMode:NSDefaultRunLoopMode];
        processEntry(requestToProcess, 900, nil);
    }
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:@"For 1 Hour" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    if(grouped){
        [[AXNManager sharedInstance] hideNotificationRequests:reqsArray];
        for (NCNotificationRequest *request in reqsArray) {
            if (![request.content.header containsString:@"Snoozed"]) {
                NSString *newTitle = [NSString stringWithFormat:@"%@ • Snoozed", request.content.header];
                [request.content setValue:newTitle forKey:@"_header"];
            }
            processEntry(request, 3600, nil);
        }
        NSTimer *timerShow = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:3600]
                                                      interval:nil
                                                       repeats:NO
                                                         block:(void (^)(NSTimer *timer))^{
                                                             for (NCNotificationRequest *request in reqsArray) {
                                                                processEntry(request, 0, nil);
                                                             }
                                                             [[AXNManager sharedInstance] showNotificationRequests:reqsArray];
                                                         }];
        [[NSRunLoop mainRunLoop] addTimer:timerShow forMode:NSDefaultRunLoopMode];
    } else {
        [[AXNManager sharedInstance] hideNotificationRequest:requestToProcess];
        if (![requestToProcess.content.header containsString:@"Snoozed"]) {
            NSString *newTitle = [NSString stringWithFormat:@"%@ • Snoozed", requestToProcess.content.header];
            [requestToProcess.content setValue:newTitle forKey:@"_header"];
        }
        NSTimer *timerShow = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:3600]
                                                      interval:nil
                                                       repeats:NO
                                                         block:(void (^)(NSTimer *timer))^{
                                                             processEntry(requestToProcess, 0, nil);
                                                             [[AXNManager sharedInstance] showNotificationRequest:requestToProcess];
                                                         }];
        [[NSRunLoop mainRunLoop] addTimer:timerShow forMode:NSDefaultRunLoopMode];
        processEntry(requestToProcess, 3600, nil);
    }
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:@"For 4 Hour" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    if(grouped){
        [[AXNManager sharedInstance] hideNotificationRequests:reqsArray];
        for (NCNotificationRequest *request in reqsArray) {
            if (![request.content.header containsString:@"Snoozed"]) {
                NSString *newTitle = [NSString stringWithFormat:@"%@ • Snoozed", request.content.header];
                [request.content setValue:newTitle forKey:@"_header"];
            }
            processEntry(request, 14400, nil);
        }
        NSTimer *timerShow = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:14400]
                                                      interval:nil
                                                       repeats:NO
                                                         block:(void (^)(NSTimer *timer))^{
                                                             for (NCNotificationRequest *request in reqsArray) {
                                                                processEntry(request, 0, nil);
                                                             }
                                                             [[AXNManager sharedInstance] showNotificationRequests:reqsArray];
                                                         }];
        [[NSRunLoop mainRunLoop] addTimer:timerShow forMode:NSDefaultRunLoopMode];
    } else {
        [[AXNManager sharedInstance] hideNotificationRequest:requestToProcess];
        if (![requestToProcess.content.header containsString:@"Snoozed"]) {
            NSString *newTitle = [NSString stringWithFormat:@"%@ • Snoozed", requestToProcess.content.header];
            [requestToProcess.content setValue:newTitle forKey:@"_header"];
        }
        NSTimer *timerShow = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:14400]
                                                      interval:nil
                                                       repeats:NO
                                                         block:(void (^)(NSTimer *timer))^{
                                                             processEntry(requestToProcess, 0, nil);
                                                             [[AXNManager sharedInstance] showNotificationRequest:requestToProcess];
                                                         }];
        [[NSRunLoop mainRunLoop] addTimer:timerShow forMode:NSDefaultRunLoopMode];
        processEntry(requestToProcess, 14400, nil);
    }
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:@"For 8 Hours" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    if(grouped){
        [[AXNManager sharedInstance] hideNotificationRequests:reqsArray];
        for (NCNotificationRequest *request in reqsArray) {
            if (![request.content.header containsString:@"Snoozed"]) {
                NSString *newTitle = [NSString stringWithFormat:@"%@ • Snoozed", request.content.header];
                [request.content setValue:newTitle forKey:@"_header"];
            }
            processEntry(request, 28800, nil);
        }
        NSTimer *timerShow = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:28800]
                                                      interval:nil
                                                       repeats:NO
                                                         block:(void (^)(NSTimer *timer))^{
                                                             for (NCNotificationRequest *request in reqsArray) {
                                                                processEntry(request, 0, nil);
                                                             }
                                                             [[AXNManager sharedInstance] showNotificationRequests:reqsArray];
                                                         }];
        [[NSRunLoop mainRunLoop] addTimer:timerShow forMode:NSDefaultRunLoopMode];
    } else {
        [[AXNManager sharedInstance] hideNotificationRequest:requestToProcess];
        if (![requestToProcess.content.header containsString:@"Snoozed"]) {
            NSString *newTitle = [NSString stringWithFormat:@"%@ • Snoozed", requestToProcess.content.header];
            [requestToProcess.content setValue:newTitle forKey:@"_header"];
        }
        NSTimer *timerShow = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:28800]
                                                      interval:nil
                                                       repeats:NO
                                                         block:(void (^)(NSTimer *timer))^{
                                                             processEntry(requestToProcess, 0, nil);
                                                             [[AXNManager sharedInstance] showNotificationRequest:requestToProcess];
                                                         }];
        [[NSRunLoop mainRunLoop] addTimer:timerShow forMode:NSDefaultRunLoopMode];
        processEntry(requestToProcess, 28800, nil);
    }
  }]];
  /*[alert addAction:[UIAlertAction actionWithTitle:@"Until DND is turned off" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    if(grouped){
        [[AXNManager sharedInstance] hideNotificationRequests:reqsArray];
    } else {
        [[AXNManager sharedInstance] hideNotificationRequest:requestToProcess];
        if (![requestToProcess.content.header containsString:@"Snoozed"]) {
            NSString *newTitle = [NSString stringWithFormat:@"%@ • Snoozed", requestToProcess.content.header];
            [requestToProcess.content setValue:newTitle forKey:@"_header"];
        }
        processEntry(requestToProcess, -2, nil);
    }
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:@"Until I leave these location" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [[AXNManager sharedInstance] hideNotificationRequest:requestToProcess];
    if (![requestToProcess.content.header containsString:@"Snoozed"]) {
        NSString *newTitle = [NSString stringWithFormat:@"%@ • Snoozed", requestToProcess.content.header];
        [requestToProcess.content setValue:newTitle forKey:@"_header"];
    }
    [NSTimer scheduledTimerWithTimeInterval:86400
                            target:[NSBlockOperation blockOperationWithBlock:^{processEntry(requestToProcess, 0, nil); [[AXNManager sharedInstance] showNotificationRequest:requestToProcess];}]
                            selector:@selector(main)
                            userInfo:nil
                            repeats:NO];
    processEntry(requestToProcess, 86400, nil);
  }]];*/

    [alert addAction:[UIAlertAction actionWithTitle:@"Specific time" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NCNotificationManagementAlertController *alertController = [[%c(NCNotificationManagementAlertController) alloc] initWithRequest:requestToProcess withPresentingView:nil settingsDelegate:nil];
        //[alertController setTitle:@"Snooze until:"]; //\n\n\n\n\n\n\n\n\n\n\n\n\n\n
        //UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        UIDatePicker *picker = [[UIDatePicker alloc] init];
        [picker setDatePickerMode:UIDatePickerModeDateAndTime];
        [picker setMinuteInterval:15];
        [picker setMinimumDate:[NSDate dateWithTimeInterval:900 sinceDate:[NSDate date]]];
        [picker setMaximumDate:[NSDate dateWithTimeInterval:604800 sinceDate:requestToProcess.timestamp]];
        [alertController.view addSubview:picker];

        SButton *button = [SButton buttonWithType:UIButtonTypeSystem];
        CGFloat margin = 4.0F;
        button.frame = CGRectMake(10 + alertController.view.bounds.origin.x, alertController.view.bounds.origin.y + ((picker.frame.size.height+40) - 2) + 50, alertController.view.frame.size.width - margin * 4.0F - 20, 50);
        [button setBackgroundColor:[UIColor systemBlueColor]];
        [button setTitle:@"Snooze" forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:19];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        button.request = requestToProcess;
        button.controllerToDismiss = alertController;
        button.pickerDate = picker.date;
        button.cell = cellToCapture;
        button.grouped = grouped;
        [button addTarget:self action:@selector(buttonDown:) forControlEvents:UIControlEventTouchDown];
        [button addTarget:self action:@selector(buttonUpCancel:) forControlEvents:UIControlEventTouchDragExit];
        [button addTarget:self action:@selector(buttonUp:) forControlEvents:UIControlEventTouchUpInside];
        button.layer.cornerRadius = 10.5;
        [alertController.view addSubview:button];

        UIImageView *myImage = [[UIImageView alloc] init];
        myImage.image = [self imageWithView:cellToCapture];
        double widthInPoints = myImage.image.size.width;
        double heightInPoints = myImage.image.size.height;
        [myImage setFrame:CGRectMake(0, 0, widthInPoints, heightInPoints)];
        myImage.contentMode = UIViewContentModeScaleAspectFit;
        
        SButton *button2 = [SButton buttonWithType:UIButtonTypeSystem];
        button2.frame = CGRectMake(10 + alertController.view.bounds.origin.x , alertController.view.bounds.origin.y+50, alertController.view.frame.size.width - margin * 4.0F - 20, heightInPoints+10);

        if (grouped) {
            [myImage setFrame:CGRectMake(button2.bounds.origin.x, button2.bounds.origin.y, button2.bounds.size.width-15, button2.bounds.size.height)];
        } else {
            [myImage setFrame:CGRectMake(button2.bounds.origin.x, button2.bounds.origin.y, button2.bounds.size.width-30, button2.bounds.size.height)];
        }

        [button2 setBackgroundColor:[UIColor systemGrayColor]];
        [button2 setAlpha:0.1f];
        button2.layer.cornerRadius = 12.5;

        [alertController.view addSubview:button2];
        [alertController.view addSubview:myImage];
        myImage.center = button2.center;

        picker.center = CGPointMake(button.center.x, picker.center.y+50+heightInPoints);
        button.frame = CGRectMake(10 + alertController.view.bounds.origin.x, alertController.view.bounds.origin.y + (picker.frame.size.height+30) + button2.frame.size.height, alertController.view.frame.size.width - margin * 4.0F - 20, 50);

        UIPopoverPresentationController *popoverController = alertController.popoverPresentationController;
        popoverController.sourceView = alertController.view;
        popoverController.sourceRect = [alertController.view bounds];

        [alertController.view addConstraint:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:alertController.view attribute:NSLayoutAttributeBottomMargin multiplier:1.0 constant:-76.0f+40.0f
        ]];

        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
                [window.rootViewController presentViewController:alertController animated:YES completion:nil];
                break;
            }
        }
    }]];

    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) {
            [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
            break;
        }
    }
}

%new
- (UIImage *) imageWithView:(UIView *)viewB {
    NCNotificationListView *superView = (NCNotificationListView *)viewB.superview;
    UIView *view;

    if (superView.grouped) {
        view = superView;
    } else {
        view = viewB;
    }

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:view.bounds.size];
	
	UIImage *imageRender = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:NO];
	}];

	renderer = nil;
    return imageRender;
}

%new
-(void)buttonDown:(UIButton *)sender {
    [UIView animateWithDuration:0.2 delay:0 options:nil animations:^{
        sender.alpha = 0.5f;
    } completion:nil];
}

%new
-(void)buttonUpCancel:(UIButton *)sender {
    [UIView animateWithDuration:0.2 delay:0 options:nil animations:^{
        sender.alpha = 1.0f;
    } completion:nil];
}

%new
-(void)buttonUp:(id)sender {
    SButton *senderFix = sender;
    [UIView animateWithDuration:0.2 delay:0 options:nil animations:^{
        senderFix.alpha = 1.0f;
    } completion:nil];
    [senderFix.controllerToDismiss dismissViewControllerAnimated:YES completion:nil];

    NCNotificationListView *cellListView = (NCNotificationListView *)senderFix.cell.superview;
    NCNotificationGroupList *groupList = cellListView.dataSource;
    NSMutableArray *reqsArray = [groupList.orderedRequests copy];

    if(senderFix.grouped) {
        [[AXNManager sharedInstance] hideNotificationRequests:reqsArray];
        for (NCNotificationRequest *request in reqsArray) {
            if (![request.content.header containsString:@"Snoozed"]) {
                NSString *newTitle = [NSString stringWithFormat:@"%@ • Snoozed", request.content.header];
                [request.content setValue:newTitle forKey:@"_header"];
            }
            processEntry(request, [senderFix.pickerDate timeIntervalSinceNow], nil);
        }
        NSTimer *timerShow = [[NSTimer alloc] initWithFireDate:senderFix.pickerDate
                                                      interval:nil
                                                       repeats:NO
                                                         block:(void (^)(NSTimer *timer))^{
                                                             for (NCNotificationRequest *request in reqsArray) {
                                                                processEntry(request, 0, nil);
                                                             }
                                                             [[AXNManager sharedInstance] showNotificationRequests:reqsArray];
                                                         }];
        [[NSRunLoop mainRunLoop] addTimer:timerShow forMode:NSDefaultRunLoopMode];
    } else {
        [[AXNManager sharedInstance] hideNotificationRequest:senderFix.request];
        if (![senderFix.request.content.header containsString:@"Snoozed"]) {
            NSString *newTitle = [NSString stringWithFormat:@"%@ • Snoozed", senderFix.request.content.header];
            [senderFix.request.content setValue:newTitle forKey:@"_header"];
        }
        NSTimer *timerShow = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:3600]
                                                      interval:nil
                                                       repeats:NO
                                                         block:(void (^)(NSTimer *timer))^{
                                                             processEntry(senderFix.request, 0, nil);
                                                             [[AXNManager sharedInstance] showNotificationRequest:senderFix.request];
                                                         }];
        [[NSRunLoop mainRunLoop] addTimer:timerShow forMode:NSDefaultRunLoopMode];

        processEntry(senderFix.request, [senderFix.pickerDate timeIntervalSinceNow], nil);
    }
}
%end

/*@interface DNDState : NSObject
@end

%hook DNDState
-(BOOL)isActive {
    BOOL isDNDActive = %orig;
    if (isDNDActive == NO) {
        NSMutableArray *entries = [config[@"entries"] mutableCopy];
        for (NSMutableDictionary *entry in entries) {
            NSString *timestampString = [NSString stringWithFormat:@"%@", entry[@"timeStamp"]];
            if ([timestampString isEqualToString:@"-2"]) {
                [[AXNManager sharedInstance] showNotificationRequest:(NCNotificationRequest *)entry[@"id"]];
                processEntry((NCNotificationRequest *)entry[@"id"], 0, nil);
            }
        }
    }
    return %orig;
}
%end*/

/*
static bool shouldStopRequest(NCNotificationRequest *request) {
  bool stop = NO;
  NSMutableArray *removeObjects = [[NSMutableArray alloc] init];
  for (NSDictionary *entry in (NSArray *)config[@"entries"]) {
    int interval = [[NSDate date] timeIntervalSince1970];
    if ([(NSString *)request.sectionIdentifier isEqualToString:(NSString *)entry[@"id"]] && (interval < [entry[@"timeStamp"] intValue] || [entry[@"timeStamp"] intValue] == -1)) {
      stop = YES;
    } else if (interval > [entry[@"timeStamp"] intValue] && [entry[@"timeStamp"] intValue] != -1) {
      [removeObjects addObject:entry];
    }
  }
  if (removeObjects) {
    [config[@"entries"] removeObjectsInArray:removeObjects];
    [config writeToFile:configPath atomically:YES];
  }
  return stop;
}
*/
%hook CSNotificationDispatcher
- (void)postNotificationRequest:(NCNotificationRequest *)arg1 {
    NSString *req = [NSString stringWithFormat:@"%@", arg1];
    NSMutableArray *entries = [config[@"entries"] mutableCopy];
    for (NSMutableDictionary *entry in entries) {
        NSMutableArray *parts = [[entry[@"id"] componentsSeparatedByString:@";"] mutableCopy];
        [parts removeObject:parts[0]];
        NSString *combinedparts = [parts componentsJoinedByString:@";"];
        if ([req containsString:combinedparts]) {
            NCNotificationRequest *argFix = arg1;
            NSString *newTitle = [NSString stringWithFormat:@"%@ • Snoozed", argFix.content.header];
            [argFix.content setValue:newTitle forKey:@"_header"];
            %orig(argFix);
            [[AXNManager sharedInstance] hideNotificationRequest:argFix];
                secondsLeft = [entry[@"timeStamp"] doubleValue] - [[NSDate date] timeIntervalSince1970] + 1;
            NSTimer *timerShow = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:secondsLeft]
                                                          interval:nil
                                                           repeats:NO
                                                             block:(void (^)(NSTimer *timer))^{
                                                                 processEntry(argFix, 0, nil);
                                                                 [[AXNManager sharedInstance] showNotificationRequest:argFix];
                                                             }];
            [[NSRunLoop mainRunLoop] addTimer:timerShow forMode:NSDefaultRunLoopMode];
            return;
        }
    }
    %orig;
}
%end

%hook SBNCScreenController
-(void)turnOnScreenForNotificationRequest:(id)arg1 {
    NSString *req = [NSString stringWithFormat:@"%@", arg1];
    NSMutableArray *entries = [config[@"entries"] mutableCopy];
    for (NSMutableDictionary *entry in entries) {
        NSMutableArray *parts = [[entry[@"id"] componentsSeparatedByString:@";"] mutableCopy];
        [parts removeObject:parts[0]];
        NSString *combinedparts = [parts componentsJoinedByString:@";"];
        if ([req containsString:combinedparts]) {
                secondsLeft = [entry[@"timeStamp"] doubleValue] - [[NSDate date] timeIntervalSince1970] + 1;
            [NSTimer scheduledTimerWithTimeInterval:secondsLeft
                                        target:[NSBlockOperation blockOperationWithBlock:^{%orig;}]
                                        selector:@selector(main)
                                        userInfo:nil
                                        repeats:NO
                                    ];
            return;
        }
    }
    %orig;
}
%end

%hook SBNCSoundController
-(void)playSoundForNotificationRequest:(id)arg1 presentingDestination:(id)arg2 {
    NSString *req = [NSString stringWithFormat:@"%@", arg1];
    NSMutableArray *entries = [config[@"entries"] mutableCopy];
    for (NSMutableDictionary *entry in entries) {
        NSMutableArray *parts = [[entry[@"id"] componentsSeparatedByString:@";"] mutableCopy];
        [parts removeObject:parts[0]];
        NSString *combinedparts = [parts componentsJoinedByString:@";"];
        if ([req containsString:combinedparts]) {
                secondsLeft = [entry[@"timeStamp"] doubleValue] - [[NSDate date] timeIntervalSince1970] + 1;
            [NSTimer scheduledTimerWithTimeInterval:secondsLeft
                                        target:[NSBlockOperation blockOperationWithBlock:^{%orig;}]
                                        selector:@selector(main)
                                        userInfo:nil
                                        repeats:NO
                                    ];
            return;
        }
    }
    %orig;
}
%end

%hook SBNotificationBannerDestination
-(void)_postNotificationRequest:(id)arg1 modal:(BOOL)arg2 completion:(/*^block*/id)arg3 {
    NSString *req = [NSString stringWithFormat:@"%@", arg1];
    NSMutableArray *entries = [config[@"entries"] mutableCopy];
    for (NSMutableDictionary *entry in entries) {
        NSMutableArray *parts = [[entry[@"id"] componentsSeparatedByString:@";"] mutableCopy];
        [parts removeObject:parts[0]];
        NSString *combinedparts = [parts componentsJoinedByString:@";"];
        if ([req containsString:combinedparts]) {
                secondsLeft = [entry[@"timeStamp"] doubleValue] - [[NSDate date] timeIntervalSince1970] + 1;
            [NSTimer scheduledTimerWithTimeInterval:secondsLeft
                                        target:[NSBlockOperation blockOperationWithBlock:^{%orig;}]
                                        selector:@selector(main)
                                        userInfo:nil
                                        repeats:NO
                                    ];
            return;
        }
    }
    %orig;
}
%end
%end

@interface NCNotificationContentView : NSObject
@end

@interface UIView (Private)
-(NSArray *)allSubviews;
@end

%group AxonVertical
%hook NCNotificationCombinedListViewController
%property (nonatomic,assign) BOOL axnAllowChanges;

-(UIEdgeInsets)insetMargins {
    if (verticalPosition == 0) return UIEdgeInsetsMake(0, -96, 0, 0);
    else return UIEdgeInsetsMake(0, 0, 0, -96);
}

-(CGSize)collectionView:(UICollectionView *)arg1 layout:(UICollectionViewLayout*)arg2 sizeForItemAtIndexPath:(id)arg3 {
    CGSize orig = %orig;
    UIView *view = [arg1 cellForItemAtIndexPath:arg3].contentView;
    for(id item in view.allSubviews) {
      if([item isKindOfClass:[objc_getClass("NCNotificationContentView") class]]) {
        return CGSizeMake(orig.width - 96, ((UIView *)item).frame.size.height+30);
      }
    }
    return CGSizeMake(orig.width - 96, orig.height);
}

%end

// iOS 13 Support
%hook NCNotificationStructuredListViewController
%property (nonatomic,assign) BOOL axnAllowChanges;
-(UIEdgeInsets)insetMargins {
    if (verticalPosition == 0) return UIEdgeInsetsMake(0, -96, 0, 0);
    else return UIEdgeInsetsMake(0, 0, 0, -96);
}
%end

#pragma mark disabled

/*%hook SBDashBoardCombinedListViewController

%property (nonatomic, retain) AXNView *axnView;

-(void)viewDidLoad{
    %orig;
    if (!initialized) {
        initialized = YES;
        self.axnView = [[AXNView alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 96, 0, 96, 500)];
        self.axnView.translatesAutoresizingMaskIntoConstraints = NO;
        self.axnView.collectionViewLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
        [AXNManager sharedInstance].view = self.axnView;
        updateViewConfiguration();

        [self.view addSubview:self.axnView];

        [NSLayoutConstraint activateConstraints:@[
            [self.axnView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
            [self.axnView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
            [self.axnView.widthAnchor constraintEqualToConstant:90]
        ]];

        if (verticalPosition == 0) {
            [NSLayoutConstraint activateConstraints:@[
                [self.axnView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[
                [self.axnView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            ]];
        }
    }
    [AXNManager sharedInstance].sbclvc = self;
}

%end*/

#pragma mark disabled

// iOS 13 Support
/*%hook CSCombinedListViewController
%property (nonatomic, retain) AXNView *axnView;
-(void)viewDidLoad{
    %orig;
    if (!initialized) {
        initialized = YES;
        self.axnView = [[AXNView alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 96, 0, 96, 500)];
        self.axnView.translatesAutoresizingMaskIntoConstraints = NO;
        self.axnView.collectionViewLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
        [AXNManager sharedInstance].view = self.axnView;
        updateViewConfiguration();

        [self.view addSubview:self.axnView];

        [NSLayoutConstraint activateConstraints:@[
            [self.axnView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
            [self.axnView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
            [self.axnView.widthAnchor constraintEqualToConstant:90]
        ]];

        if (verticalPosition == 0) {
            [NSLayoutConstraint activateConstraints:@[
                [self.axnView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[
                [self.axnView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            ]];
        }
    }
    [AXNManager sharedInstance].sbclvc = self;
}
%end*/

%end

%group AxonHorizontal

%hook SBDashBoardCombinedListViewController

-(void)viewDidLoad{
    %orig;
    [AXNManager sharedInstance].sbclvc = self;
}

%end

// iOS 13 Support
%hook CSCombinedListViewController
-(void)viewDidLoad{
    %orig;
    [AXNManager sharedInstance].sbclvc = self;
}
%end

#pragma mark disabled

/*%hook SBDashBoardNotificationAdjunctListViewController

%property (nonatomic, retain) AXNView *axnView;

-(void)viewDidLoad {
    %orig;

    if (!initialized) {
        initialized = YES;
        UIStackView *stackView = [self valueForKey:@"_stackView"];
        self.axnView = [[AXNView alloc] initWithFrame:CGRectMake(0,0,64,90)];
        self.axnView.translatesAutoresizingMaskIntoConstraints = NO;
        [AXNManager sharedInstance].view = self.axnView;
        updateViewConfiguration();

        [stackView addArrangedSubview:self.axnView];

        [NSLayoutConstraint activateConstraints:@[
            [self.axnView.centerXAnchor constraintEqualToAnchor:stackView.centerXAnchor],
            [self.axnView.leadingAnchor constraintEqualToAnchor:stackView.leadingAnchor constant:10],
            [self.axnView.trailingAnchor constraintEqualToAnchor:stackView.trailingAnchor constant:-10],
            // [self.axnView.heightAnchor constraintEqualToConstant:90]
        ]];


        if (style <= 3) {
            [NSLayoutConstraint activateConstraints:@[
                [self.axnView.heightAnchor constraintEqualToConstant:90]
            ]];
        } else if (style ==4){
            [NSLayoutConstraint activateConstraints:@[
                [self.axnView.heightAnchor constraintEqualToConstant:30]
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[
                [self.axnView.heightAnchor constraintEqualToConstant:40]
            ]];
        }
    }
}

// This is used to make the Axon view last, e.g. when media controls are presented. 

-(void)_updatePresentingContent {
    %orig;
    UIStackView *stackView = [self valueForKey:@"_stackView"];
    [stackView removeArrangedSubview:self.axnView];
    [stackView addArrangedSubview:self.axnView];
}

-(void)_insertItem:(id)arg1 animated:(BOOL)arg2 {
    %orig;
    UIStackView *stackView = [self valueForKey:@"_stackView"];
    [stackView removeArrangedSubview:self.axnView];
    [stackView addArrangedSubview:self.axnView];
}

// Let Springboard know we have a little surprise for it. 

-(BOOL)isPresentingContent {
    return YES;
}

%end*/

#pragma mark disabled

/*%hook CSNotificationAdjunctListViewController
%property (nonatomic, retain) AXNView *axnView;
-(void)viewDidLoad {
    %orig;

    if (!initialized) {
        initialized = YES;
        UIStackView *stackView = [self valueForKey:@"_stackView"];
        self.axnView = [[AXNView alloc] initWithFrame:CGRectMake(0,0,64,90)];
        self.axnView.translatesAutoresizingMaskIntoConstraints = NO;
        [AXNManager sharedInstance].view = self.axnView;
        updateViewConfiguration();

        [stackView addArrangedSubview:self.axnView];

        [NSLayoutConstraint activateConstraints:@[
            [self.axnView.centerXAnchor constraintEqualToAnchor:stackView.centerXAnchor],
            [self.axnView.leadingAnchor constraintEqualToAnchor:stackView.leadingAnchor constant:10],
            [self.axnView.trailingAnchor constraintEqualToAnchor:stackView.trailingAnchor constant:-10],
            // [self.axnView.heightAnchor constraintEqualToConstant:90]
        ]];


        if (style <= 3) {
            [NSLayoutConstraint activateConstraints:@[
                [self.axnView.heightAnchor constraintEqualToConstant:90]
            ]];
        } else if (style ==4){
            [NSLayoutConstraint activateConstraints:@[
                [self.axnView.heightAnchor constraintEqualToConstant:30]
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[
                [self.axnView.heightAnchor constraintEqualToConstant:40]
            ]];
        }
    }
}

-(void)_updatePresentingContent {
    %orig;
    UIStackView *stackView = [self valueForKey:@"_stackView"];
    [stackView removeArrangedSubview:self.axnView];
    [stackView addArrangedSubview:self.axnView];
}
-(void)_insertItem:(id)arg1 animated:(BOOL)arg2 {
    %orig;
    UIStackView *stackView = [self valueForKey:@"_stackView"];
    [stackView removeArrangedSubview:self.axnView];
    [stackView addArrangedSubview:self.axnView];
}

-(BOOL)isPresentingContent {
    return YES;
}
%end*/

#pragma mark disabled

/*@interface NCNotificationListSectionHeaderView : UIView
@end

%hook NCNotificationListSectionHeaderView
// Remove Section Header Text

- (void)layoutSubviews
{
    self.hidden = 1;
}
- (CGRect)frame 
{
    return CGRectZero;
}
- (void)setFrame:(CGRect)arg1
{
    %orig(CGRectZero);
}
%end*/

%end

%group AxonIntegrityFail

%hook SBIconController

%property (retain,nonatomic) WKWebView *axnIntegrityView;

-(void)loadView{
    %orig;
    if (!dpkgInvalid) return;
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    self.axnIntegrityView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:configuration];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://piracy.kritanta.me/"]];
    [self.axnIntegrityView loadRequest:request];
    [self.view addSubview:self.axnIntegrityView];
    [self.view sendSubviewToBack:self.axnIntegrityView];
}

-(void)viewDidAppear:(BOOL)animated{
    %orig;
    if (!dpkgInvalid) return;
    UIAlertController *alertController = [UIAlertController
        alertControllerWithTitle:@"😡😡😡"
        message:@"The build of Axon you're using comes from an untrusted source. Pirate repositories can distribute malware and you will get subpar user experience using any tweaks from them.\nRemember: Axon is free. Uninstall this build and install the proper version of Axon from:\nhttps://repo.kritanta.me/\n(it's free, damnit, why would you pirate that!?)\n\nIf you're seeing this message but have obtained Axon from an official source, add https://repo.kritanta.me/ to Cydia or Sileo and respring."
        preferredStyle:UIAlertControllerStyleAlert
    ];

    [alertController addAction:[UIAlertAction actionWithTitle:@"Damn!" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIApplication *application = [UIApplication sharedApplication];
        [application openURL:[NSURL URLWithString:@"https://repo.kritanta.me/"] options:@{} completionHandler:nil];

        [self dismissViewControllerAnimated:YES completion:NULL];
    }]];

    [self presentViewController:alertController animated:YES completion:NULL];
}

%end

%end

/* Hide all notifications on open. */

static void displayStatusChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[AXNManager sharedInstance].view reset];
    [[AXNManager sharedInstance].view refresh];
}

static void *observer = NULL;

static void reloadPrefs() 
{
    if ([NSHomeDirectory() isEqualToString:@"/var/mobile"]) 
    {
        CFArrayRef keyList = CFPreferencesCopyKeyList((CFStringRef)kIdentifier, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);

        if (keyList) 
        {
            prefs = (NSDictionary *)CFBridgingRelease(CFPreferencesCopyMultiple(keyList, (CFStringRef)kIdentifier, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));

            if (!prefs) 
            {
                prefs = [NSDictionary new];
            }
            CFRelease(keyList);
        }
    } 
    else 
    {
        prefs = [NSDictionary dictionaryWithContentsOfFile:kSettingsPath];
    }
}


static BOOL boolValueForKey(NSString *key, BOOL defaultValue) 
{
    return (prefs && [prefs objectForKey:key]) ? [[prefs objectForKey:key] boolValue] : defaultValue;
}

static void preferencesChanged() 
{
    CFPreferencesAppSynchronize((CFStringRef)kIdentifier);
    reloadPrefs();

    enabled = boolValueForKey(@"Enabled", YES);
    vertical = boolValueForKey(@"Vertical", NO);
    hapticFeedback = boolValueForKey(@"HapticFeedback", YES);
    badgesEnabled = boolValueForKey(@"BadgesEnabled", YES);
    badgesShowBackground = boolValueForKey(@"BadgesShowBackground", YES);
    darkMode = boolValueForKey(@"DarkMode", NO);
    sortingMode = [prefs objectForKey:@"SortingMode"] ? [[prefs valueForKey:@"SortingMode"] intValue] : 0;
    selectionStyle = [prefs objectForKey:@"SelectionStyle"] ? [[prefs valueForKey:@"SelectionStyle"] intValue] : 0;
    style = [prefs objectForKey:@"Style"] ? [[prefs valueForKey:@"Style"] intValue] : 0;
    showByDefault = [prefs objectForKey:@"ShowByDefault"] ? [[prefs valueForKey:@"ShowByDefault"] intValue] : 0;
    alignment = [prefs objectForKey:@"Alignment"] ? [[prefs valueForKey:@"Alignment"] intValue] : 0;
    verticalPosition = [prefs objectForKey:@"VerticalPosition"] ? [[prefs valueForKey:@"VerticalPosition"] intValue] : 0;
    spacing = [prefs objectForKey:@"Spacing"] ? [[prefs valueForKey:@"Spacing"] floatValue] : 10.0;
    fadeEntireCell = boolValueForKey(@"FadeCell", YES);
    BOOL dynamicBadges = boolValueForKey(@"dynamicBadges", YES);

    [AXNManager sharedInstance].style = style;
    [AXNManager sharedInstance].fadeEntireCell = fadeEntireCell;
    [AXNManager sharedInstance].dynamicBadges = dynamicBadges;


    updateViewConfiguration();
}

#pragma mark my addition
@interface CCUIContentModuleContentContainerView : UIView
@end

@interface CCUIContentModuleBackgroundView : UIView
@end 

@interface MTMaterialView : UIView
@end 

@interface CCUIRoundButton : UIControl
@property (nonatomic, retain) MTMaterialView *normalStateBackgroundView;
- (void)_unhighlight;
- (void)setHighlighted:(bool)arg1;
@end

@interface CCUILabeledRoundButton : UIView
@property (nonatomic, assign) bool centered;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, assign) bool labelsVisible;
@property (nonatomic, retain) UIImage *glyphImage;
@property (nonatomic, retain) CCUIRoundButton *buttonView;
- (id)initWithGlyphImage:(id)arg1 highlightColor:(id)arg2 useLightStyle:(BOOL)arg3;
- (void)updatePosition;
@end

@interface CCUILabeledRoundButtonViewController : UIViewController
@property (nonatomic,copy) NSString *title;
@property (nonatomic,copy) NSString *subtitle;
@property (nonatomic, retain) UIColor *highlightColor;
@property (nonatomic, assign) bool labelsVisible;
@property (nonatomic, retain) CCUILabeledRoundButton *buttonContainer;
@property (nonatomic, retain) CCUIRoundButton *button;
-(id)initWithGlyphImage:(id)arg1 highlightColor:(id)arg2 useLightStyle:(BOOL)arg3 ;
@end

@interface CCUIDisplayBackgroundViewController : UIViewController
@property (nonatomic, retain) CCUILabeledRoundButtonViewController *nightShiftButton;
@property (nonatomic, retain) CCUILabeledRoundButtonViewController *trueToneButton;
@end

@interface CCUIContentModuleContainerViewController : UIViewController
@property (nonatomic,copy) NSString *moduleIdentifier;
@property (nonatomic,strong,readwrite) CCUIContentModuleBackgroundView *backgroundView;
@property (nonatomic,retain) CCUIDisplayBackgroundViewController *backgroundViewController;
@property (nonatomic, retain) CCUILabeledRoundButtonViewController *darkButton;
@end

@interface CAPackage : NSObject
@property (readonly) CALayer *rootLayer;
@property (readonly) BOOL geometryFlipped;
+ (id)packageWithContentsOfURL:(id)arg1 type:(id)arg2 options:(id)arg3 error:(id)arg4;
- (id)_initWithContentsOfURL:(id)arg1 type:(id)arg2 options:(id)arg3 error:(id)arg4;
@end

extern NSString const *kCAPackageTypeCAMLBundle;

@interface CCUICAPackageView : UIView
@property (nonatomic, retain) CAPackage *package;
- (void)setStateName:(id)arg1;
@end

@interface CCUIDuneButton : CCUIRoundButton
@property (nonatomic, retain) UIView *backgroundView;
@property (nonatomic, retain) CCUICAPackageView *packageView;
- (id)initWithGlyphImage:(id)arg1 highlightColor:(id)arg2 useLightStyle:(BOOL)arg3;
- (void)updateStateAnimated:(bool)arg1;
@end

static BOOL isDNDEnabled;
static BOOL isDuneEnabled;
static CGRect ccBounds;
static UIImage *nightImage;
static UIImage *toneImage;
static BOOL shouldSnooze;

static void setDuneEnabled(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
  isDuneEnabled = YES;
  [[NSNotificationCenter defaultCenter] postNotificationName:@"xyz.skitty.dune.update" object:nil userInfo:nil];
}

static void setDuneDisabled(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
  isDuneEnabled = NO;
  [[NSNotificationCenter defaultCenter] postNotificationName:@"xyz.skitty.dune.update" object:nil userInfo:nil];
}

%group Toggle
%subclass CCUIDuneButton : CCUIRoundButton
%property (nonatomic, retain) UIView *backgroundView;
%property (nonatomic, retain) CCUICAPackageView *packageView;
- (void)layoutSubviews {
  %orig;
  if (!self.packageView) {
    self.backgroundView = [[UIView alloc] initWithFrame:self.bounds];
    self.backgroundView.userInteractionEnabled = NO;
    self.backgroundView.layer.cornerRadius = self.bounds.size.width/2;
    self.backgroundView.layer.masksToBounds = YES;
    self.backgroundView.backgroundColor = [UIColor redColor];
    self.backgroundView.alpha = 0;
    [self addSubview:self.backgroundView];

    self.packageView = [[%c(CCUICAPackageView) alloc] initWithFrame:self.bounds];
    self.packageView.package = [CAPackage packageWithContentsOfURL:[NSURL fileURLWithPath:@"/Library/Application Support/Dune/StyleMode.ca"] type:kCAPackageTypeCAMLBundle options:nil error:nil];
    [self.packageView setStateName:@"dark"];
    [self addSubview:self.packageView];

    [self setHighlighted:NO];
    [self updateStateAnimated:NO];
  }
}
- (void)touchesEnded:(id)arg1 withEvent:(id)arg2 {
  %orig;
  if (isDuneEnabled) {
    shouldSnooze = YES;
    CFPreferencesSetAppValue((CFStringRef)@"enabled", (CFPropertyListRef)[NSNumber numberWithBool:NO], CFSTR("com.skitty.dune"));
  } else {
    shouldSnooze = NO;
    CFPreferencesSetAppValue((CFStringRef)@"enabled", (CFPropertyListRef)[NSNumber numberWithBool:YES], CFSTR("com.skitty.dune"));
  }

  //refreshPrefs();
  [self updateStateAnimated:YES];
}
%new
- (void)updateStateAnimated:(bool)animated {
  if (!isDuneEnabled) {
    ((CCUILabeledRoundButton *)self.superview).subtitle = [NSString stringWithFormat:@"On"];
    [self.packageView setStateName:@"On"];
    if (animated) {
      [UIView animateWithDuration:0.2 delay:0 options:nil animations:^{
        self.backgroundView.alpha = 1;
      } completion:nil];
    } else {
      self.backgroundView.alpha = 1;
    }
  } else {
    ((CCUILabeledRoundButton *)self.superview).subtitle = @"Off";
    [self.packageView setStateName:@"Off"];
    if (animated) {
      [UIView animateWithDuration:0.2 delay:0 options:nil animations:^{
        self.backgroundView.alpha = 0;
      } completion:nil];
    } else {
      self.backgroundView.alpha = 0;
    }
  }
}
%end

%hook CCUIContentModuleContainerViewController
%property (nonatomic, retain) CCUILabeledRoundButtonViewController *darkButton;
- (void)setExpanded:(bool)arg1 {
  %orig;
  if (arg1 && [self.moduleIdentifier containsString:@"donot"]) {
    ccBounds = self.view.superview.bounds;
    if (!self.darkButton) {
      self.darkButton = [[%c(CCUILabeledRoundButtonViewController) alloc] initWithGlyphImage:nil highlightColor:nil useLightStyle:NO];
      self.darkButton.buttonContainer = [[%c(CCUILabeledRoundButton) alloc] initWithGlyphImage:nil highlightColor:nil useLightStyle:NO];
      [self.darkButton.buttonContainer setFrame:CGRectMake(0, 0, 72, 91)];
      [self.darkButton.buttonContainer setBounds:CGRectMake(self.darkButton.buttonContainer.frame.origin.x, self.darkButton.buttonContainer.frame.origin.y, self.darkButton.buttonContainer.frame.size.width+10, self.darkButton.buttonContainer.frame.size.height)];
      self.darkButton.view = self.darkButton.buttonContainer;
      self.darkButton.buttonContainer.buttonView = [[%c(CCUIDuneButton) alloc] initWithGlyphImage:nil highlightColor:nil useLightStyle:NO];
      [self.darkButton.buttonContainer addSubview:self.darkButton.buttonContainer.buttonView];
      self.darkButton.button = self.darkButton.buttonContainer.buttonView;

      self.darkButton.title = @"Snooze";
      if (isDuneEnabled) {
        self.darkButton.subtitle = [NSString stringWithFormat:@"On"];
        [((CCUIDuneButton *)self.darkButton.buttonContainer.buttonView).packageView setStateName:@"On"];
      } else {
        self.darkButton.subtitle = @"Off";
        [((CCUIDuneButton *)self.darkButton.buttonContainer.buttonView).packageView setStateName:@"Off"];
      }
      [self.darkButton setLabelsVisible:YES];

      [self.backgroundView addSubview:self.darkButton.buttonContainer];
    }
    [self.darkButton.buttonContainer updatePosition];
    self.darkButton.buttonContainer.alpha = 1;
  }
}
%end

%hook CCUILabeledRoundButton
%property (nonatomic, assign) bool centered;
- (void)setCenter:(CGPoint)center {
  if (self.centered) {
    return;
  } else {
    self.centered = YES;
    %orig;
  }
}
%new
- (void)updatePosition {
  self.centered = NO;
  CGPoint center;
  if ([self.title isEqual: @"Snooze"]) {
    if (ccBounds.size.width < ccBounds.size.height) {
      center.x = ccBounds.size.width/2;
      center.y = ccBounds.size.height-ccBounds.size.height*0.14;
    } else {
      center.x = ccBounds.size.width-ccBounds.size.width*0.14;
      center.y = ccBounds.size.height/2;
    }
  }
  [self setCenter:center];
}
%end

%hook DNDState
-(BOOL)isActive {
  isDNDEnabled = %orig;
  return %orig;
}
%end
%end

%ctor{
    preferencesChanged();
    
    NSLog(@"[Axon] init");

    dpkgInvalid = ![[NSFileManager defaultManager] fileExistsAtPath:@"/var/lib/dpkg/info/me.nepeta.axon.list"];
    /*if (!dpkgInvalid) dpkgInvalid = !([[NSFileManager defaultManager] fileExistsAtPath:@"/private/var/lib/apt/lists/repo.nepeta.me_._Release"]
    || [[NSFileManager defaultManager] fileExistsAtPath:@"/private/var/mobile/Library/Caches/com.saurik.Cydia/lists/repo.nepeta.me_._Release"]
    || [[NSFileManager defaultManager] fileExistsAtPath:@"/private/var/mobile/Documents/xyz.willy.Zebra/zebra.db"]);*/
    if (!dpkgInvalid) dpkgInvalid = ![[NSFileManager defaultManager] fileExistsAtPath:@"/var/lib/dpkg/info/me.nepeta.axon.md5sums"];

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        &observer,
        (CFNotificationCallback)preferencesChanged,
        (CFStringRef)@"me.nepeta.axon/ReloadPrefs",
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );

    if (!dpkgInvalid && enabled) {
        BOOL ok = false;

        ok = ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"/var/lib/dpkg/info/%@%@%@%@%@%@%@%@%@.axon.md5sums", @"m", @"e", @".", @"n", @"e", @"p", @"e", @"t", @"a"]]
                /* &&
                ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"/private/var/lib/apt/lists/repo.%@%@%@%@%@%@.me_._Release", @"n", @"e", @"p", @"e", @"t", @"a"]] ||
                [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"/private/var/mobile/Library/Caches/com.saurik.Cydia/lists/repo.%@%@%@%@%@%@.me_._Release", @"n", @"e", @"p", @"e", @"t", @"a"]] ||
                [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"/private/var/mobile/Documents/xyz.willy.Zebra/%@%@%@%@%@.db", @"z", @"e", @"b", @"r", @"a"]])*/
        );

        if (ok && [@"nepeta" isEqualToString:@"nepeta"]) {
            %init(Axon);
            if (!vertical) {
                %init(AxonHorizontal);
            } else {
                %init(AxonVertical);
            }
            CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, displayStatusChanged, CFSTR("com.apple.iokit.hid.displayStatus"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
            return;
        } else {
            dpkgInvalid = YES;
        }
    }

    if (enabled) %init(AxonIntegrityFail);

    #pragma mark my addition

    %init(Toggle);

    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:[NSNumber numberWithInt:501] forKey:NSFileOwnerAccountID];
    [attributes setObject:[NSNumber numberWithInt:501] forKey:NSFileGroupOwnerAccountID];

    NSFileManager *manager = [NSFileManager defaultManager];

    if (![manager fileExistsAtPath:configPath]) {
        if(![manager fileExistsAtPath:configPath.stringByDeletingLastPathComponent isDirectory:nil]) {
            [manager createDirectoryAtPath:configPath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:attributes error:NULL];
        }
        [manager createFileAtPath:configPath contents:nil attributes:attributes];
        [@{@"entries":@[]} writeToFile:configPath atomically:YES];
    }
        config = [NSMutableDictionary dictionaryWithContentsOfFile:configPath];
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, setDuneEnabled, CFSTR("xyz.skitty.dune.enabled"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, setDuneDisabled, CFSTR("xyz.skitty.dune.disabled"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
