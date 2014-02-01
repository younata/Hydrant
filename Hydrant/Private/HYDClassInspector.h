#import <Foundation/Foundation.h>


@interface HYDClassInspector : NSObject

@property (strong, nonatomic, readonly) NSArray *allProperties;
@property (strong, nonatomic, readonly) NSArray *weakProperties;
@property (strong, nonatomic, readonly) NSArray *nonWeakProperties;

+ (instancetype)inspectorForClass:(Class)aClass;
- (id)initWithClass:(Class)aClass;

@end
