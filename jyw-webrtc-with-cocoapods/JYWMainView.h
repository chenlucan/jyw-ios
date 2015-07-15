
#import <UIKit/UIKit.h>

@class JYWMainView;

@protocol JYWMainViewDelegate <NSObject>

- (void)mainView:(JYWMainView *)mainView didInputRoom:(NSString *)room;
- (void)start;
- (void)stop;
@end

// The main view of AppRTCDemo. It contains an input field for entering a room
// name on apprtc to connect to.
@interface JYWMainView : UIView

@property(nonatomic, weak) id<JYWMainViewDelegate> delegate;

@end
