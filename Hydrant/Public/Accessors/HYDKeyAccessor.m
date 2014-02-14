#import "HYDKeyAccessor.h"
#import "HYDClassInspector.h"
#import "HYDProperty.h"
#import "HYDError.h"
#import "HYDFunctions.h"

@interface HYDKeyAccessor ()
@property (strong, nonatomic) NSArray *keys;
@end

@implementation HYDKeyAccessor

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithKeys:(NSArray *)keys
{
    self = [super init];
    if (self) {
        self.keys = keys;
    }
    return self;
}

#pragma mark - <NSObject>

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[self class]] && [self.keys isEqual:[(HYDKeyAccessor *)object keys]];
}

- (NSUInteger)hash
{
    return self.keys.hash;
}

- (NSString *)description
{
    if (self.keys.count == 1) {
        return [NSString stringWithFormat:@"<%@: %@>", NSStringFromClass([self class]), self.keys[0]];
    } else {
        return [NSString stringWithFormat:@"<%@: [%@]>", NSStringFromClass([self class]), [self.keys componentsJoinedByString:@", "]];
    }
}

#pragma mark - <NSCopying>

- (id)copyWithZone:(NSZone *)zone
{
    return self; // I don't mutate
}

#pragma mark - <HYDAccessor>

- (NSArray *)fieldNames
{
    NSMutableArray *names = [NSMutableArray arrayWithCapacity:self.keys.count];
    for (NSString *name in self.keys) {
        [names addObject:HYDKeyToString(name)];
    }
    return names;
}

- (NSArray *)valuesFromSourceObject:(id)sourceObject error:(__autoreleasing HYDError **)error
{
    if (!sourceObject) {
        HYDSetObjectPointer(error, [HYDError errorWithCode:HYDErrorGetViaAccessorFailed
                                              sourceObject:sourceObject
                                            sourceAccessor:self
                                         destinationObject:nil
                                       destinationAccessor:nil
                                                   isFatal:YES
                                          underlyingErrors:nil]);
        return nil;
    }

    NSMutableArray *values = [NSMutableArray arrayWithCapacity:self.keys.count];
    for (NSString *key in self.keys) {
        if ([self canReadKey:key fromSourceObject:sourceObject]) {
            id value = [sourceObject valueForKey:key];
            [values addObject:value];
        } else {
            return nil; // We should return an error; but for backwards compatibility
        }
    }
    return values;
}

- (HYDError *)setValues:(NSArray *)values ofClasses:(NSArray *)destinationClasses onObject:(id)destinationObject
{
    if (self.keys.count != values.count) {
        return [HYDError errorWithCode:HYDErrorSetViaAccessorFailed
                          sourceObject:nil
                        sourceAccessor:nil
                     destinationObject:destinationObject
                   destinationAccessor:self
                               isFatal:YES
                      underlyingErrors:nil];
    }

    NSUInteger index = 0;
    for (NSString *key in self.keys) {
        id value = values[index];
        // for backwards compat: don't assign NSNull if it should be doing this...
        if ([[NSNull null] isEqual:value] /* && ![self requiresNSNullForClass:destinationClasses[index]]*/) {
            value = nil;
        }
        // for easier debuggability, we're opting to potentially explode here
        [destinationObject setValue:value forKey:key];
        ++index;
    }
    return nil;
}

#pragma mark - Private

- (BOOL)canReadKey:(NSString *)key fromSourceObject:(id)sourceObject
{
    if ([sourceObject respondsToSelector:@selector(objectForKey:)]) {
        if ([sourceObject valueForKey:key]) {
            return YES;
        }
    }

    HYDClassInspector *inspector = [HYDClassInspector inspectorForClass:[sourceObject class]];
    for (HYDProperty *property in inspector.allProperties) {
        if ([property.name isEqual:key]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)requiresNSNullForClass:(Class)theClass
{
    NSArray *nullableClasses = @[[NSDictionary class], [NSHashTable class], [NSArray class], [NSOrderedSet class]];
    for (Class nullableClass in nullableClasses) {
        if ([theClass isSubclassOfClass:nullableClass]) {
            return YES;
        }
    }
    return NO;
}

@end


HYD_EXTERN
HYDKeyAccessor *HYDAccessKeyFromArray(NSArray *fields)
{
    if (fields.count == 0) {
        return nil;
    }
    return [[HYDKeyAccessor alloc] initWithKeys:fields];
}
