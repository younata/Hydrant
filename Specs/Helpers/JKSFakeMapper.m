#import "JKSFakeMapper.h"
#import "JKSError.h"

@implementation JKSFakeMapper {
    NSMutableArray *_objectsToReturn;
    NSMutableArray *_errorsToReturn;
    NSMutableArray *_sourceObjectsReceived;
}

- (id)init
{
    return [self initWithDestinationKey:nil];
}

- (id)initWithDestinationKey:(NSString *)destinationKey
{
    self = [super init];
    if (self) {
        _objectsToReturn = [NSMutableArray array];
        _errorsToReturn = [NSMutableArray array];
        _sourceObjectsReceived = [NSMutableArray array];
        self.destinationKey = destinationKey;
    }
    return self;
}

#pragma mark - Properties

- (void)setObjectsToReturn:(NSArray *)objectsToReturn
{
    _objectsToReturn = [objectsToReturn mutableCopy];
}

- (void)setErrorsToReturn:(NSArray *)errorsToReturn
{
    _errorsToReturn = [errorsToReturn mutableCopy];
}

- (void)setSourceObjectsReceived:(NSArray *)sourceObjectsReceived
{
    _sourceObjectsReceived = [sourceObjectsReceived mutableCopy];
}


#pragma mark - <JKSMapper>

- (id)objectFromSourceObject:(id)sourceObject error:(__autoreleasing JKSError **)error
{
    [_sourceObjectsReceived addObject:sourceObject ?: [NSNull null]];

    *error = nil;

    if (self.errorsToReturn.count && ![self.errorsToReturn[0] isEqual:[NSNull null]]) {
        *error = self.errorsToReturn[0];
    }
    if (self.errorsToReturn.count > 1) {
        [_errorsToReturn removeObjectAtIndex:0];
    }

    id object = nil;

    if (self.objectsToReturn.count && ![self.objectsToReturn[0] isEqual:[NSNull null]]) {
        object = self.objectsToReturn[0];
    }
    if (self.objectsToReturn.count > 1) {
        [_objectsToReturn removeObjectAtIndex:0];
    }
    return object;
}

- (void)setupAsChildMapperWithMapper:(id<JKSMapper>)mapper factory:(id<JKSFactory>)factory
{
    self.rootMapperReceived = mapper;
    self.factoryReceived = factory;
}

- (id<JKSMapper>)reverseMapperWithDestinationKey:(NSString *)destinationKey
{
    self.reverseMapperDestinationKeyReceived = destinationKey;
    return self.reverseMapperToReturn;
}

@end
