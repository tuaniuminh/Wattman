#import "WattmanCardView.h"

@interface WattmanCardView ()
@property (nonatomic, strong) UIStackView *rowsStackView;
@end

@implementation WattmanCardView

- (instancetype)initWithTitle:(NSString *)title icon:(NSString *)icon {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.layer.cornerRadius = 18.0;
        self.layer.masksToBounds = YES;
        
        // Nền mờ kính mờ / Dynamic Color tương thích iOS 12/13+
        if (@available(iOS 13.0, *)) {
            self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        } else {
            self.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
        }
        
        // Header (Icon + Title)
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
        if (@available(iOS 13.0, *)) {
            _titleLabel.textColor = [UIColor secondaryLabelColor];
        } else {
            _titleLabel.textColor = [UIColor darkGrayColor];
        }
        
        if (icon && icon.length > 0) {
            _titleLabel.text = [NSString stringWithFormat:@"%@  %@", icon, [title uppercaseString]];
        } else {
            _titleLabel.text = [title uppercaseString];
        }
        [self addSubview:_titleLabel];
        
        // Rows stack
        _rowsStackView = [[UIStackView alloc] init];
        _rowsStackView.translatesAutoresizingMaskIntoConstraints = NO;
        _rowsStackView.axis = UILayoutConstraintAxisVertical;
        _rowsStackView.spacing = 10.0;
        _rowsStackView.alignment = UIStackViewAlignmentFill;
        _rowsStackView.distribution = UIStackViewDistributionEqualSpacing;
        [self addSubview:_rowsStackView];
        
        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:14],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
            
            [_rowsStackView.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:12],
            [_rowsStackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
            [_rowsStackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
            [_rowsStackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-16]
        ]];
    }
    return self;
}

- (void)addRowWithLabel:(NSString *)labelText valueLabel:(UILabel *)valueLabel {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    
    UILabel *lbl = [[UILabel alloc] init];
    lbl.translatesAutoresizingMaskIntoConstraints = NO;
    lbl.text = labelText;
    lbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    if (@available(iOS 13.0, *)) {
        lbl.textColor = [UIColor labelColor];
    } else {
        lbl.textColor = [UIColor blackColor];
    }
    
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    valueLabel.textAlignment = NSTextAlignmentRight;
    if (@available(iOS 13.0, *)) {
        valueLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        valueLabel.textColor = [UIColor darkGrayColor];
    }
    
    [row addSubview:lbl];
    [row addSubview:valueLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [lbl.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [lbl.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        
        [valueLabel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [valueLabel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [valueLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:lbl.trailingAnchor constant:12],
        
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:22]
    ]];
    
    [_rowsStackView addArrangedSubview:row];
}

@end
