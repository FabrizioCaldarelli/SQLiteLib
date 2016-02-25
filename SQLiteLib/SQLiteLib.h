//
//  SQLiteLib.h
//  SQLiteLib
//
//  Created by Fabrizio on 24/02/16.
//  Copyright © 2016 Fabrizio Caldarelli. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

/**
 * SQLiteProtocol
 */
@protocol SQLiteProtocol <NSObject>

@optional
- (NSString*)SQLiteTableName;

@required

// Array of SQLiteField
- (NSArray*)SQLiteFields;

@end



/**
 * SQLiteConfig
*/
@interface SQLiteConfig : NSObject

@property (nonatomic, strong) NSString *pathFile;

- (SQLiteConfig*)initWithPathFile:(NSString*)pathFile;

@end

/**
 * SQLiteError
 */
@interface SQLiteError : NSObject

@property (nonatomic, assign) int code;
@property (nonatomic, strong) NSString *message;


@end

/**
 * SQLiteDatabase
 */
@interface SQLiteDatabase : NSObject

@property (nonatomic, assign) sqlite3 *db;
@property (nonatomic, strong) SQLiteConfig *config;

// TableName
- (NSString*)tableName:(Class)classVar;

- (void)executeSql:(NSString*)sql error:(SQLiteError**)error;
- (void)createTable:(Class)classVar error:(SQLiteError**)error;
- (void)dropTable:(Class)classVar error:(SQLiteError**)error;
- (void)insert:(NSObject<SQLiteProtocol>*)object error:(SQLiteError**)error;
- (void)insertAll:(NSArray*)arrObject error:(SQLiteError**)error;
- (void)close;

@end

/**
 * SQLiteLib
 */
@interface SQLiteLib : NSObject

+ (SQLiteDatabase*)openDatabase:(SQLiteConfig*)config error:(SQLiteError**)error;

@end


/**
 * SQLiteFieldExtra
 */
@interface SQLiteFieldExtra : NSObject

typedef enum
{
    SQLiteFieldExtraTypePrimaryKey,
    SQLiteFieldExtraTypeItemClass          // params : { @"classVar": class }
}SQLiteFieldExtraType;


@property (nonatomic, assign) SQLiteFieldExtraType type;
@property (nonatomic, strong) NSDictionary *params;

- (SQLiteFieldExtra*)initWithType:(SQLiteFieldExtraType)type params:(NSDictionary*)params;

+ (SQLiteFieldExtra*)primaryKey;
+ (SQLiteFieldExtra*)itemClass:(Class)classVar;


@end


/**
 * SQLiteField
 */
@interface SQLiteField : NSObject

typedef enum
{
    SQLiteFieldTypeBoolean,
    SQLiteFieldTypeInteger,
    SQLiteFieldTypeFloat,
    SQLiteFieldTypeString,
    SQLiteFieldTypeDateTime,
    SQLiteFieldTypeArray,
}SQLiteFieldType;


@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) SQLiteFieldType type;
@property (nonatomic, strong) NSArray *extra;       // Array of SQLiteFieldExtra

- (SQLiteField*)initWithName:(NSString*)name type:(SQLiteFieldType)type extra:(NSArray*)extra;

+ (SQLiteField*)field:(NSString*)name type:(SQLiteFieldType)type extra:(NSArray*)extra;
+ (SQLiteField*)field:(NSString*)name type:(SQLiteFieldType)type;


- (BOOL)containsExtraType:(SQLiteFieldExtraType)extra;
+ (SQLiteField*)primaryKeyField:(NSObject*)object;

- (NSString*)sqliteFieldType;
- (void)bindToSqliteStatement:(sqlite3_stmt *)stmt object:(NSObject<SQLiteProtocol>*)object index:(int)index;

@end