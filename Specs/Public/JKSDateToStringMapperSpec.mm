#import "JKSDateToStringMapper.h"
#import "JKSError.h"
#import "JKSStringToDateMapper.h"

using namespace Cedar::Matchers;
using namespace Cedar::Doubles;

SPEC_BEGIN(JKSDateToStringMapperSpec)

describe(@"JKSDateToStringMapper", ^{
    __block JKSDateToStringMapper *mapper;
    __block NSDate *date;
    __block NSString *dateString;
    __block NSError *error;
    __block id sourceObject;
    __block id parsedObject;

    beforeEach(^{
        error = nil;

        NSDateComponents *referenceDateComponents = [[NSDateComponents alloc] init];
        referenceDateComponents.year = 2012;
        referenceDateComponents.month = 2;
        referenceDateComponents.day = 1;
        referenceDateComponents.hour = 14;
        referenceDateComponents.minute = 30;
        referenceDateComponents.second = 45;
        referenceDateComponents.calendar = [NSCalendar currentCalendar];
        referenceDateComponents.timeZone = [NSTimeZone defaultTimeZone];
        date = [referenceDateComponents date];
        dateString = @"2012-02-01 at 14:30:45";

        mapper = JKSDateToString(@"dateKey", @"yyyy-MM-dd 'at' HH:mm:ss");
    });

    it(@"should have the same destination key it was given", ^{
        mapper.destinationKey should equal(@"dateKey");
    });

    void (^itShouldConvertDatesToStrings)() = ^{
        context(@"when given a date", ^{
            beforeEach(^{
                sourceObject = date;
            });

            it(@"should not produce an error", ^{
                error should be_nil;
            });

            it(@"should produce a string", ^{
                parsedObject should equal(dateString);
            });
        });

        context(@"when given another object", ^{
            beforeEach(^{
                sourceObject = @"Yo";
            });

            it(@"should produce an error", ^{
                error.domain should equal(JKSErrorDomain);
                error.code should equal(JKSErrorInvalidSourceObjectValue);
            });

            it(@"should return nil", ^{
                parsedObject should be_nil;
            });
        });

        context(@"when given nil", ^{
            beforeEach(^{
                sourceObject = nil;
            });

            it(@"should not produce an error", ^{
                error should be_nil;
            });

            it(@"should produce nil", ^{
                parsedObject should be_nil;
            });
        });
    };

    describe(@"parsing the source object", ^{
        subjectAction(^{
            parsedObject = [mapper objectFromSourceObject:sourceObject error:&error];
        });

        itShouldConvertDatesToStrings();
    });

    describe(@"reverse mapper", ^{
        __block JKSStringToDateMapper *reverseMapper;
        beforeEach(^{
            reverseMapper = [mapper reverseMapperWithDestinationKey:@"otherKey"];
        });

        it(@"should have the given key as its new destination key", ^{
            reverseMapper.destinationKey should equal(@"otherKey");
        });

        it(@"should be the inverse of the current mapper", ^{
            sourceObject = date;
            parsedObject = [mapper objectFromSourceObject:sourceObject error:&error];
            error should be_nil;

            id result = [reverseMapper objectFromSourceObject:parsedObject error:&error];
            error should be_nil;

            result should equal(sourceObject);
        });
    });
});

SPEC_END