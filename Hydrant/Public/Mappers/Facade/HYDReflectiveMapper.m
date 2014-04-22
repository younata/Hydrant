#import "HYDReflectiveMapper.h"
#import "HYDConstants.h"
#import "HYDIdentityMapper.h"
#import "HYDIdentityValueTransformer.h"
#import "HYDObjectMapper.h"
#import "HYDClassInspector.h"
#import "HYDProperty.h"
#import "HYDOptionalMapper.h"
#import "HYDTypedMapper.h"
#import "HYDStringToURLMapper.h"
#import "HYDConstants.h"
#import "HYDAccessor.h"
#import "HYDDefaultAccessor.h"
#import "HYDFunctions.h"
#import "HYDReversedReflectiveMapper.h"
#import "HYDStringToNumberMapper.h"
#import "HYDStringToDateMapper.h"
#import "HYDDotNetDateFormatter.h"
#import "HYDFirstMapper.h"

#import "HYDReflectiveMapper+Protected.h"
#import "HYDMapping.h"


@implementation HYDReflectiveMapper

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithMapper:(id<HYDMapper>)innerMapper
         sourceClass:(Class)sourceClass
    destinationClass:(Class)destinationClass
{
    return [self initWithMapper:innerMapper
                    sourceClass:sourceClass
               destinationClass:destinationClass
                 optionalFields:[NSSet set]
                 excludedFields:[NSSet set]
              overriddenMapping:@{}
                    typeMapping:@{NSStringFromClass([NSURL class]): HYDMapStringToURL(),
                                  NSStringFromClass([NSNumber class]): HYDMapStringToDecimalNumber(),
                                  NSStringFromClass([NSDate class]): HYDMapFirst(HYDMapStringToDate(HYDDateFormatRFC3339_milliseconds),
                                                                                 HYDMapStringToDate(HYDDateFormatRFC3339),
                                                                                 HYDMapStringToDate([HYDDotNetDateFormatter new]),
                                                                                 HYDMapStringToDate(HYDDateFormatRFC822),
                                                                                 HYDMapStringToDate(HYDDateFormatRFC822_day),
                                                                                 HYDMapStringToDate(HYDDateFormatRFC822_day_gmt),
                                                                                 HYDMapStringToDate(HYDDateFormatRFC822_day_seconds),
                                                                                 HYDMapStringToDate(HYDDateFormatRFC822_day_seconds_gmt),
                                                                                 HYDMapStringToDate(HYDDateFormatRFC822_seconds),
                                                                                 HYDMapStringToDate(HYDDateFormatRFC822_seconds_gmt),
                                                                                 HYDMapStringToDate(HYDDateFormatRFC822_gmt))}
                 keyTransformer:[HYDIdentityValueTransformer new]];
}

- (id)initWithMapper:(id<HYDMapper>)innerMapper
         sourceClass:(Class)sourceClass
    destinationClass:(Class)destinationClass
      optionalFields:(NSSet *)optionalFields
      excludedFields:(NSSet *)excludedFields
   overriddenMapping:(NSDictionary *)overriddenMapping
         typeMapping:(NSDictionary *)typeMapping
      keyTransformer:(NSValueTransformer *)keyTransformer
{
    self = [super init];
    if (self) {
        self.innerMapper = innerMapper;
        self.sourceClass = sourceClass;
        self.destinationClass = destinationClass;
        self.optionalFields = optionalFields;
        self.excludedFields = excludedFields;
        self.typeMapping = typeMapping;

        self.overriddenMapping = HYDNormalizeKeyValueDictionary(overriddenMapping, ^id(NSArray *keys) {
            return HYDAccessDefault(keys);
        });
        self.destinationToSourceKeyTransformer = keyTransformer;
    }
    return self;
}

#pragma mark - <NSObject>

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %@ -> %@>",
            NSStringFromClass(self.class),
            NSStringFromClass(self.sourceClass),
            NSStringFromClass(self.destinationClass)];
}

#pragma mark - <HYDMapper>

- (id)objectFromSourceObject:(id)sourceObject error:(__autoreleasing HYDError **)error
{
    return [self.internalMapper objectFromSourceObject:sourceObject error:error];
}

- (id<HYDMapper>)reverseMapper
{
    id<HYDMapper> reversedInnerMapper = [self.innerMapper reverseMapper];

    return [[HYDReversedReflectiveMapper alloc] initWithMapper:reversedInnerMapper
                                                   sourceClass:self.destinationClass
                                              destinationClass:self.sourceClass
                                                optionalFields:self.optionalFields
                                                excludedFields:self.excludedFields
                                             overriddenMapping:HYDReversedKeyValueDictionary(self.overriddenMapping)
                                                   typeMapping:self.typeMapping
                                                keyTransformer:self.destinationToSourceKeyTransformer];
}

#pragma mark - Public

- (HYDReflectiveMapper *(^)(Class destinationClass, id<HYDMapper> mapper))mapClass
{
    return ^(Class destinationClass, id<HYDMapper> mapper) {
        NSMutableDictionary *newClassMapping = [self.typeMapping mutableCopy];
        newClassMapping[NSStringFromClass(destinationClass)] = mapper;
        return [[[self class] alloc] initWithMapper:self.innerMapper
                                        sourceClass:self.sourceClass
                                   destinationClass:self.destinationClass
                                     optionalFields:self.optionalFields
                                     excludedFields:self.excludedFields
                                  overriddenMapping:self.overriddenMapping
                                        typeMapping:newClassMapping
                                     keyTransformer:self.keyTransformer];
    };
}

- (HYDReflectiveMapper *(^)(NSArray *))optional
{
    return ^(NSArray *optionalFields) {
        return [[[self class] alloc] initWithMapper:self.innerMapper
                                        sourceClass:self.sourceClass
                                   destinationClass:self.destinationClass
                                     optionalFields:[NSSet setWithArray:optionalFields]
                                     excludedFields:self.excludedFields
                                  overriddenMapping:self.overriddenMapping
                                        typeMapping:self.typeMapping
                                     keyTransformer:self.keyTransformer];
    };
}

- (HYDReflectiveMapper *(^)(NSArray *))except
{
    return ^(NSArray *excludedFields) {
        return [[[self class] alloc] initWithMapper:self.innerMapper
                                        sourceClass:self.sourceClass
                                   destinationClass:self.destinationClass
                                     optionalFields:self.optionalFields
                                     excludedFields:[NSSet setWithArray:excludedFields]
                                  overriddenMapping:self.overriddenMapping
                                        typeMapping:self.typeMapping
                                     keyTransformer:self.keyTransformer];
    };
}

- (HYDReflectiveMapper *(^)(NSDictionary *))customMapping
{
    return ^(NSDictionary *overriddenMapping) {
        return [[[self class] alloc] initWithMapper:self.innerMapper
                                        sourceClass:self.sourceClass
                                   destinationClass:self.destinationClass
                                     optionalFields:self.optionalFields
                                     excludedFields:self.excludedFields
                                  overriddenMapping:overriddenMapping
                                        typeMapping:self.typeMapping
                                     keyTransformer:self.keyTransformer];
    };
}

- (HYDReflectiveMapper *(^)(NSValueTransformer *propertyToSourceKeyTransformer))keyTransformer
{
    return ^(NSValueTransformer *propertyToSourceKeyTransformer) {
        return [[[self class] alloc] initWithMapper:self.innerMapper
                                        sourceClass:self.sourceClass
                                   destinationClass:self.destinationClass
                                     optionalFields:self.optionalFields
                                     excludedFields:self.excludedFields
                                  overriddenMapping:self.overriddenMapping
                                        typeMapping:self.typeMapping
                                     keyTransformer:propertyToSourceKeyTransformer];
    };
}

#pragma mark - Private

- (id<HYDMapper>)internalMapper
{
    if (!_internalMapper) {
        _internalMapper = HYDMapType(HYDMapKVCObject(self.innerMapper, self.sourceClass, self.destinationClass, [self buildMapping]),
                                     self.sourceClass, self.destinationClass);
    }
    return _internalMapper;
}

#pragma mark - Protected

- (NSDictionary *)buildMapping
{
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    HYDClassInspector *inspector = [HYDClassInspector inspectorForClass:self.destinationClass];

    for (HYDProperty *property in inspector.allProperties) {
        NSString *sourceKey = [self.destinationToSourceKeyTransformer transformedValue:property.name];
        NSString *destinationKey = property.name;
        if (!sourceKey || !destinationKey) {
            continue;
        }

        if ([self.excludedFields containsObject:destinationKey]) {
            continue;
        }

        id<HYDMapper> mapper = HYDMapNotNullFrom([self mapperForProperty:property]);
        if ([self.optionalFields containsObject:destinationKey]) {
            mapper = HYDMapNonFatally(mapper);
        }

        results[sourceKey] = HYDMap(mapper, HYDAccessDefault(destinationKey));
    }

    [results addEntriesFromDictionary:self.overriddenMapping];
    return results;
}

- (id<HYDMapper>)mapperForProperty:(HYDProperty *)property
{
    id<HYDMapper> mapper = HYDMapIdentity();

    if ([property isObjCObjectType]) {
        Class propertyClass = [property classType];
        id<HYDMapper> classMapper = self.typeMapping[NSStringFromClass(propertyClass)]; // TODO: repeat for super classes
        mapper = HYDMapType(classMapper ?: mapper, nil, propertyClass);
    }

    return mapper;
}

@end


HYD_EXTERN_OVERLOADED
HYDReflectiveMapper *HYDMapReflectively(id<HYDMapper> innerMapper, Class sourceClass, Class destinationClass)
{
    return [[HYDReflectiveMapper alloc] initWithMapper:innerMapper
                                           sourceClass:sourceClass
                                      destinationClass:destinationClass];
}

HYD_EXTERN_OVERLOADED
HYDReflectiveMapper *HYDMapReflectively(id<HYDMapper> innerMapper, Class destinationClass)
{
    return HYDMapReflectively(innerMapper, [NSDictionary class], destinationClass);
}

HYD_EXTERN_OVERLOADED
HYDReflectiveMapper *HYDMapReflectively(Class sourceClass, Class destinationClass)
{
    return HYDMapReflectively(HYDMapIdentity(), sourceClass, destinationClass);
}

HYD_EXTERN_OVERLOADED
HYDReflectiveMapper *HYDMapReflectively(Class destinationClass)
{
    return HYDMapReflectively([NSDictionary class], destinationClass);
}
