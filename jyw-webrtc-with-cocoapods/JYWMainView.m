
#import "JYWMainView.h"

#import "UIImage+ARDUtilities.h"

// TODO(tkchin): retrieve status bar height dynamically.
static CGFloat const kStatusBarHeight = 20;

static CGFloat const kRoomTextButtonSize = 40;
static CGFloat const kRoomTextFieldHeight = 40;
static CGFloat const kRoomTextFieldMargin = 8;
static CGFloat const kAppLabelHeight = 20;

@class JYWRoomTextField;
@protocol JYWRoomTextFieldDelegate <NSObject>
- (void)roomTextField:(JYWRoomTextField *)roomTextField
         didInputRoom:(NSString *)room;
@end

// Helper view that contains a text field and a clear button.
@interface JYWRoomTextField : UIView <UITextFieldDelegate>
@property(nonatomic, weak) id<JYWRoomTextFieldDelegate> delegate;
@end

@implementation JYWRoomTextField {
  UITextField *_roomText;
  UIButton *_clearButton;
}

@synthesize delegate = _delegate;

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _roomText = [[UITextField alloc] initWithFrame:CGRectZero];
    _roomText.borderStyle = UITextBorderStyleNone;
    _roomText.font = [UIFont fontWithName:@"Roboto" size:12];
    _roomText.placeholder = @"Room name";
    _roomText.delegate = self;
    [_roomText addTarget:self
                  action:@selector(textFieldDidChange:)
        forControlEvents:UIControlEventEditingChanged];
    [self addSubview:_roomText];

    _clearButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *image = [UIImage imageForName:@"ic_clear_black_24dp.png"
                                     color:[UIColor colorWithWhite:0 alpha:.4]];

    [_clearButton setImage:image forState:UIControlStateNormal];
    [_clearButton addTarget:self
                      action:@selector(onClear:)
            forControlEvents:UIControlEventTouchUpInside];
    _clearButton.hidden = YES;
    [self addSubview:_clearButton];

    // Give rounded corners and a light gray border.
    self.layer.borderWidth = 1;
    self.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    self.layer.cornerRadius = 2;
  }
  return self;
}

- (void)layoutSubviews {
  CGRect bounds = self.bounds;
  _clearButton.frame = CGRectMake(CGRectGetMaxX(bounds) - kRoomTextButtonSize,
                                  CGRectGetMinY(bounds),
                                  kRoomTextButtonSize,
                                  kRoomTextButtonSize);
  _roomText.frame = CGRectMake(
      CGRectGetMinX(bounds) + kRoomTextFieldMargin,
      CGRectGetMinY(bounds),
      CGRectGetMinX(_clearButton.frame) - CGRectGetMinX(bounds) -
          kRoomTextFieldMargin,
      kRoomTextFieldHeight);
}

- (CGSize)sizeThatFits:(CGSize)size {
  size.height = kRoomTextFieldHeight;
  return size;
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidEndEditing:(UITextField *)textField {
  [_delegate roomTextField:self didInputRoom:textField.text];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  // There is no other control that can take focus, so manually resign focus
  // when return (Join) is pressed to trigger |textFieldDidEndEditing|.
  [textField resignFirstResponder];
  return YES;
}

#pragma mark - Private

- (void)textFieldDidChange:(id)sender {
  [self updateClearButton];
}

- (void)onClear:(id)sender {
  _roomText.text = @"";
  [self updateClearButton];
  [_roomText resignFirstResponder];
}

- (void)updateClearButton {
  _clearButton.hidden = _roomText.text.length == 0;
}

@end

@interface JYWMainView () <JYWRoomTextFieldDelegate>
@end

@implementation JYWMainView {
  UILabel *_appLabel;
  JYWRoomTextField *_roomText;
  UIButton *_startButton;
}

@synthesize delegate = _delegate;

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _appLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _appLabel.text = @"AppRTCDemo";
    _appLabel.font = [UIFont fontWithName:@"Roboto" size:34];
    _appLabel.textColor = [UIColor colorWithWhite:0 alpha:.2];
    [_appLabel sizeToFit];
    [self addSubview:_appLabel];

    _roomText = [[JYWRoomTextField alloc] initWithFrame:CGRectZero];
    _roomText.delegate = self;
    [self addSubview:_roomText];
      
    _startButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_startButton addTarget:self
                     action:@selector(onStart:)
           forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_startButton];

    self.backgroundColor = [UIColor whiteColor];
  }
  return self;
}

- (void)layoutSubviews {
  CGRect bounds = self.bounds;
  CGFloat roomTextWidth = bounds.size.width - 2 * kRoomTextFieldMargin;
  CGFloat roomTextHeight = [_roomText sizeThatFits:bounds.size].height;
  _roomText.frame = CGRectMake(kRoomTextFieldMargin,
                               kStatusBarHeight + kRoomTextFieldMargin,
                               roomTextWidth,
                               roomTextHeight);
  _appLabel.center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
}

#pragma mark - JYWRoomTextFieldDelegate

- (void)roomTextField:(JYWRoomTextField *)roomTextField
         didInputRoom:(NSString *)room {
  [_delegate mainView:self didInputRoom:room];
}

#pragma mark - start button touch event
- (void)onStart:(id)sender {
    // kick JYWMainViewDelegate to start create connection and offer
}

@end
