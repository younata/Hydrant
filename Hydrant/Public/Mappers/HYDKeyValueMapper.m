#import "HYDKeyValueMapper.h"
#import "HYDFactory.h"
#import "HYDObjectFactory.h"
#import "HYDError.h"
#import "HYDIdentityMapper.h"
#import "HYDClassInspector.h"
#import "HYDProperty.h"
#import "HYDFunctions.h"


@interface HYDKeyValueMapper ()

@property (copy, nonatomic) NSString *destinationKey;
@property (strong, nonatomic) Class sourceClass;
@property (strong, nonatomic) Class destinationClass;
@property (strong, nonatomic) NSDictionary *mapping;
@property (strong, nonatomic) id<HYDFactory> factory;

@end


@implementation HYDKeyValueMapper

- (id)initWithDestinationKey:(NSString *)destinationKey fromClass:(Class)sourceClass toClass:(Class)destinationClass mapping:(NSDictionary *)mapping
{
    self = [super init];
    if (self) {
        self.destinationKey = destinationKey;
        self.sourceClass = sourceClass;
        self.destinationClass = destinationClass;
        self.mapping = HYDNormalizeKeyValueDictionary(mapping);
        self.factory = [[HYDObjectFactory alloc] init];
    }
    return self;
}

#pragma mark - <HYDMapper>

- (id)objectFromSourceObject:(id)sourceObject error:(__autoreleasing HYDError **)error
{
    HYDSetError(error, nil);
    if (!sourceObject) {
        *error = nil;
        return nil;
    }

    NSMutableArray *errors = [NSMutableArray array];
    BOOL hasFatalError = NO;

    id destinationObject = [self.factory newObjectOfClass:self.destinationClass];
    for (NSString *sourceKey in self.mapping) {
        id<HYDMapper> mapper = self.mapping[sourceKey];
        HYDError *innerError = nil;

        id sourceValue = nil;
        if ([self hasKey:sourceKey onObject:sourceObject]) {
            sourceValue = [self valueForKey:sourceKey onObject:sourceObject];
        }

        id destinationValue = [mapper objectFromSourceObject:sourceValue error:&innerError];

        if (innerError) {
            hasFatalError = hasFatalError || [innerError isFatal];
            [errors addObject:[HYDError errorFromError:innerError
                                   prependingSourceKey:sourceKey
                                     andDestinationKey:nil
                               replacementSourceObject:sourceValue
                                               isFatal:innerError.isFatal]];
            continue;
        }

        if ([[NSNull null] isEqual:destinationValue] && ![self requiresNSNullForClass:self.destinationClass]) {
            destinationValue = nil;
        }

        [self setValue:destinationValue forKey:mapper.destinationKey onObject:destinationObject];
    }

    if (errors.count) {
        HYDSetError(error, [HYDError errorWithCode:HYDErrorMultipleErrors
                                      sourceObject:sourceObject
                                         sourceKey:nil
                                 destinationObject:nil
                                    destinationKey:self.destinationKey
                                           isFatal:hasFatalError
                                  underlyingErrors:errors]);
    }

    if (hasFatalError) {
        return nil;
    }

    return destinationObject;
}

- (id<HYDMapper>)reverseMapperWithDestinationKey:(NSString *)destinationKey
{
    NSMutableDictionary *invertedMapping = [NSMutableDictionary dictionaryWithCapacity:self.mapping.count];
    for (NSString *sourceKey in self.mapping) {
        id<HYDMapper> mapper = self.mapping[sourceKey];

        invertedMapping[mapper.destinationKey] = [mapper reverseMapperWithDestinationKey:sourceKey];
    }
    return [[[self class] alloc] initWithDestinationKey:destinationKey
                                              fromClass:self.destinationClass
                                                toClass:self.sourceClass
                                                mapping:invertedMapping];
}

#pragma mark - Protected

- (BOOL)hasKey:(NSString *)key onObject:(id)target
{
    if ([target respondsToSelector:@selector(objectForKey:)]) {
        if ([target valueForKey:key]) {
            return YES;
        }
    }

    HYDClassInspector *inspector = [HYDClassInspector inspectorForClass:[target class]];
    for (HYDProperty *property in inspector.allProperties) {
        if ([property.name isEqual:key]) {
            return YES;
        }
    }
    return NO;
}

- (id)valueForKey:(NSString *)key onObject:(id)target
{
    return [target valueForKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key onObject:(id)target
{
    [target setValue:value forKey:key];
}

- (BOOL)requiresNSNullForClass:(Class)aClass
{
    NSArray *nullableClasses = @[[NSDictionary class], [NSHashTable class]];
    for (Class nullableClass in nullableClasses) {
        if ([aClass isSubclassOfClass:nullableClass]) {
            return YES;
        }
    }
    return NO;
}

@end


HYD_EXTERN
HYDKeyValueMapper *HYDMapObject(NSString *destinationKey, Class sourceClass, Class destinationClass, NSDictionary *mapping)
{
    return [[HYDKeyValueMapper alloc] initWithDestinationKey:destinationKey
                                                   fromClass:sourceClass
                                                     toClass:destinationClass
                                                     mapping:mapping];
}
