//
//  GTRepositoryTest.m
//  ObjectiveGitFramework
//
//  Created by Timothy Clem on 2/21/11.
//
//  The MIT License
//
//  Copyright (c) 2011 Tim Clem
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "Contants.h"


@interface GTRepositoryTest : SenTestCase {

	GTRepository *repo;
	NSString *testContent;
	GTObjectType testContentType;
}
@end


@implementation GTRepositoryTest
 
- (void)setUp {
	
	NSError *error = nil;
    repo = [GTRepository repositoryWithURL:[NSURL fileURLWithPath:TEST_REPO_PATH(self.class)] error:&error];
	testContent = @"my test data\n";
	testContentType = GTObjectTypeBlob;
}

- (void)testCreateRepositoryInDirectory {
	
	NSError *error = nil;
	NSFileManager *fm = [[NSFileManager alloc] init];
	NSURL *newRepoURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"unit_test"]];
	
	if([fm fileExistsAtPath:[newRepoURL path]]) {
		[fm removeItemAtPath:[newRepoURL path] error:&error];
		STAssertNil(error, [error localizedDescription]);
	}
	
    STAssertTrue([GTRepository initializeEmptyRepositoryAtURL:newRepoURL error:&error], nil);
	GTRepository *newRepo = [GTRepository repositoryWithURL:newRepoURL error:&error];
	
	STAssertNil(error, [error localizedDescription]);
	STAssertNotNil(newRepo, nil);
	STAssertNotNil(newRepo.fileURL, nil);
	STAssertNotNil(newRepo.repository, nil);
}

- (void)testFailsToOpenNonExistentRepo {
	
	NSError *error = nil;
	GTRepository *badRepo = [GTRepository repositoryWithURL:[NSURL fileURLWithPath:@"fake/1235"] error:&error];
	
	STAssertNil(badRepo, nil);
	STAssertNotNil(error, nil);
	NSLog(@"error = %@", [error localizedDescription]);
}

- (void)testCanTellIfAnObjectExists {
	
	NSError *error = nil;
	STAssertTrue([repo.objectDatabase containsObjectWithSha:@"8496071c1b46c854b31185ea97743be6a8774479" error:&error], nil);
	STAssertTrue([repo.objectDatabase containsObjectWithSha:@"1385f264afb75a56a5bec74243be9b367ba4ca08" error:&error], nil);
	STAssertFalse([repo.objectDatabase containsObjectWithSha:@"ce08fe4884650f067bd5703b6a59a8b3b3c99a09" error:&error], nil);
	STAssertFalse([repo.objectDatabase containsObjectWithSha:@"8496071c1c46c854b31185ea97743be6a8774479" error:&error], nil);
}

- (void)testCanReadObjectFromDb {
	
	NSError *error = nil;
	GTOdbObject *rawObj = [repo.objectDatabase objectWithSha:@"8496071c1b46c854b31185ea97743be6a8774479" error:&error];
	
	STAssertNil(error, [error localizedDescription]);
	STAssertNotNil(rawObj, nil);
	
	NSString *string = [[NSString alloc] initWithData:[rawObj data] encoding:NSUTF8StringEncoding];
	STAssertEqualObjects(@"tree 181037049a54a1eb5fab404658a3a250b44335d7", [string substringToIndex:45], nil);
	STAssertEquals((int)[rawObj.data length], 172, nil);
	STAssertEquals(rawObj.type, GTObjectTypeCommit, nil);
}

- (void)testReadingFailsOnUnknownObjects {
	
	NSError *error = nil;
	GTOdbObject *rawObj = [repo.objectDatabase objectWithSha:@"a496071c1b46c854b31185ea97743be6a8774471" error:&error];
	
	STAssertNil(rawObj, nil);
	STAssertNotNil(error, nil);
	NSLog(@"error = %@", [error localizedDescription]);
}

- (void)testCanHashData {
	
	NSError *error = nil;
	NSString *sha = [GTRepository hash:testContent objectType:testContentType error:&error];
	STAssertEqualObjects(sha, @"76b1b55ab653581d6f2c7230d34098e837197674", nil);
}

- (void)testCanWriteToDb {
	
	NSError *error = nil;
	NSString *sha = [repo.objectDatabase shaByInsertingString:testContent objectType:testContentType error:&error];
	
	STAssertNil(error, [error localizedDescription]);
	STAssertNotNil(sha, nil);
	STAssertEqualObjects(sha, @"76b1b55ab653581d6f2c7230d34098e837197674", nil);
	STAssertTrue([repo.objectDatabase containsObjectWithSha:sha error:&error], nil);
	
	rm_loose(self.class, sha);
}

- (void)testCanWalk {
	
	NSError *error = nil;
	// alloc and init to verify memory management
	GTRepository *aRepo = [[GTRepository alloc] initWithURL:[NSURL fileURLWithPath:TEST_REPO_PATH(self.class)] error:&error];
	NSString *sha = @"a4a7dce85cf63874e984719f4fdd239f5145052f";
	NSMutableArray *commits = [NSMutableArray array];
    [aRepo enumerateCommitsBeginningAtSha:sha 
                                    error:&error 
                               usingBlock:^(GTCommit *commit, BOOL *stop) {
                                   [commits addObject:commit];
                               }];
	STAssertNil(error, [error localizedDescription]);
	
	NSArray *expectedShas = [NSArray arrayWithObjects:
							 @"a4a7d",
							 @"c4780",
							 @"9fd73",
							 @"4a202",
							 @"5b5b0",
							 @"84960",
							 nil];
	for(int i=0; i < [expectedShas count]; i++) {
		GTCommit *commit = [commits objectAtIndex:i];
		STAssertEqualObjects([commit.sha substringToIndex:5], [expectedShas objectAtIndex:i], nil);
	}
	
}

- (void)testCanWalkALot {
	
	NSError *error = nil;
	GTRepository *aRepo = [GTRepository repositoryWithURL:[NSURL fileURLWithPath:TEST_REPO_PATH(self.class)] error:&error];
	NSString *sha = @"a4a7dce85cf63874e984719f4fdd239f5145052f";
	
	for(int i=0; i < 100; i++) {
		__block NSInteger count = 0;
        [aRepo enumerateCommitsBeginningAtSha:sha error:&error usingBlock:^(GTCommit *commit, BOOL *stop) {
            count++;
        }];
		STAssertNil(error, [error localizedDescription]);
		STAssertEquals(6, (int)count, nil);
		
		//[[NSGarbageCollector defaultCollector] collectExhaustively];
	}
}

- (void)testCanSelectCommits {
	
	NSError *error = nil;
	GTRepository *aRepo = [GTRepository repositoryWithURL:[NSURL fileURLWithPath:TEST_REPO_PATH(self.class)] error:&error];
	NSString *sha = @"a4a7dce85cf63874e984719f4fdd239f5145052f";
	
	__block NSInteger count = 0;
	NSArray *commits = [aRepo selectCommitsBeginningAtSha:sha error:&error block:^BOOL(GTCommit *commit, BOOL *stop) {
		count++;
		if(count > 2) *stop = YES;
		return [[commit parents] count] < 2;
	}];
	
	STAssertEquals(2, (int)[commits count], nil);
	NSArray *expectedShas = [NSArray arrayWithObjects:@"c4780", @"9fd73", nil];
	for(int i=0; i < [expectedShas count]; i++) {
		GTCommit *commit = [commits objectAtIndex:i];
		STAssertEqualObjects([commit.sha substringToIndex:5], [expectedShas objectAtIndex:i], nil);
	}
}

- (void)testLookupHead {
	
	NSError *error = nil;
	GTReference *head = [repo headReferenceWithError:&error];
	STAssertNil(error, [error localizedDescription]);
	STAssertEqualObjects(head.target, @"36060c58702ed4c2a40832c51758d5344201d89a", nil);
	STAssertEqualObjects(head.type, @"commit", nil);
}

- (void)testIsEmpty {
	STAssertFalse([repo isEmpty], nil);
}

//- (void) testCanGetRemotes {
//    NSArray* remotesArray = [repo remoteNames];
//    
//    STAssertTrue( [remotesArray containsObject: @"github"], @"remotes name did not contain expected remote" );
//    STAssertTrue( [repo hasRemoteNamed: @"github"], @"remotes name was not found by query function" );
//    
//}

// This messes other tests up b/c it writes a new HEAD, but doesn't set it back again
/*
- (void)testLookupHeadThenCommitAndThenLookupHeadAgain {
	
	NSError *error = nil;
	GTReference *head = [repo headAndReturnError:&error];
	STAssertNil(error, [error localizedDescription]);
	STAssertEqualObjects(head.target, @"36060c58702ed4c2a40832c51758d5344201d89a", nil);
	STAssertEqualObjects(head.type, @"commit", nil);
	
	NSString *tsha = @"c4dc1555e4d4fa0e0c9c3fc46734c7c35b3ce90b";
	GTObject *aObj = [repo lookupBySha:tsha error:&error];

	STAssertNotNil(aObj, [error localizedDescription]);
	STAssertTrue([aObj isKindOfClass:[GTTree class]], nil);
	GTTree *tree = (GTTree *)aObj;
	GTSignature *person = [[[GTSignature alloc] 
							initWithName:@"Tim" 
							email:@"tclem@github.com" 
							time:[NSDate date]] autorelease];
	GTCommit *commit = [GTCommit commitInRepo:repo updateRefNamed:@"HEAD" author:person committer:person message:@"new message" tree:tree parents:nil error:&error];
	STAssertNotNil(commit, [error localizedDescription]);
	NSLog(@"wrote sha %@", commit.sha);
	
	head = [repo headAndReturnError:&error];
	STAssertNotNil(head, [error localizedDescription]);
	
	STAssertEqualObjects(head.target, commit.sha, nil);
	
	rm_loose(commit.sha);
}
*/
@end
