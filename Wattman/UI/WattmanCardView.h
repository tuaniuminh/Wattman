#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WattmanCardView : UIView

- (instancetype)initWithTitle:(NSString *)title icon:(nullable NSString *)icon;

@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UIView *contentContainer;

- (void)addRowWithLabel:(NSString *)label valueLabel:(UILabel *)valueLabel;

@end

NS_ASSUME_NONNULL_END
