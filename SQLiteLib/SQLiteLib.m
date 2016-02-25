//
//  SQLiteLib.m
//  SQLiteLib
//
//  Created by Fabrizio on 24/02/16.
//  Copyright © 2016 Fabrizio Caldarelli. All rights reserved.
//

#import "SQLiteLib.h"


/**
 * SQLiteConfig
 */
@implementation SQLiteConfig

- (SQLiteConfig*)initWithPathFile:(NSString*)pathFile
{
    self = [self init];
    self.pathFile = pathFile;
    return self;
}

@end

/**
 * SQLiteError
 */
@implementation SQLiteError

+ (SQLiteError*)createFromDatabase:(sqlite3*)db
{
    int errCode = sqlite3_errcode(db);
    NSString *errMsg = [NSString stringWithUTF8String:sqlite3_errmsg(db)];
    
    SQLiteError *err = [[SQLiteError alloc] init];
    err.code = errCode;
    err.message = errMsg;
    return err;
}


@end

/**
 * SQLiteDatabase
 */
@implementation SQLiteDatabase


- (void)executeSql:(NSString*)sql error:(SQLiteError**)error
{
    *error = NULL;
    
    const char *sqlStatement = [sql UTF8String];
    sqlite3_stmt *compiledStatement;
    if(sqlite3_prepare_v2(self.db, sqlStatement,-1, &compiledStatement, NULL) == SQLITE_OK)
    {
        if(sqlite3_step(compiledStatement) != SQLITE_DONE)
        {
            *error = [SQLiteError createFromDatabase:self.db];
        }
    }
    else
    {
        *error = [SQLiteError createFromDatabase:self.db];
    }
    sqlite3_finalize(compiledStatement);
}

- (void)executeInsertOrUpdate:(NSString*)sql object:(id<SQLiteProtocol>)object error:(SQLiteError**)error
{
    *error = NULL;
    
    const char *sqlStatement = [sql UTF8String];
    sqlite3_stmt *compiledStatement;
    if(sqlite3_prepare_v2(self.db, sqlStatement,-1, &compiledStatement, NULL) == SQLITE_OK)
    {
        
        NSArray *classFields = [object SQLiteFields];
        for(int k=0;k<classFields.count;k++)
        {
            SQLiteField *f = [classFields objectAtIndex:k];
            [f bindToSqliteStatement:compiledStatement object:object index:(k+1)];
        }
        
        if(sqlite3_step(compiledStatement) != SQLITE_DONE)
        {
            *error = [SQLiteError createFromDatabase:self.db];
        }
    }
    else
    {
        *error = [SQLiteError createFromDatabase:self.db];
    }
    sqlite3_finalize(compiledStatement);
}

// TableName
- (NSString*)tableName:(Class)classVar
{
    NSString *s = NSStringFromClass(classVar);
    if([classVar conformsToProtocol:@protocol(SQLiteProtocol)])
    {
        id<SQLiteProtocol> obj = [classVar alloc];
        if([obj respondsToSelector:@selector(SQLiteTableName)])
        {
            s = [obj SQLiteTableName];
        }
    }
    
    return s;
}

// --- CreateTable
- (NSString*)prepareCreateTableSql:(Class)classVar
{
    NSString *sql = nil;
    
    if([classVar conformsToProtocol:@protocol(SQLiteProtocol)])
    {
        NSMutableArray *sqlFields = [NSMutableArray array];
        
        NSArray *classFields = [[classVar alloc] SQLiteFields];
        for (SQLiteField *f in classFields)
        {
            NSString *name = f.name;
            NSString *sqliteType = [f sqliteFieldType];
            
            NSString *sqlF = [NSString stringWithFormat:@"%@ %@", name, sqliteType];
            [sqlFields addObject:sqlF];
        }
        
        NSString *strSqlFields = [sqlFields componentsJoinedByString:@","];
        
        NSString *tableName = [self tableName:classVar];
        
        sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@);", tableName, strSqlFields];
    }
    
    return sql;
}
- (void)createTable:(Class)classVar error:(SQLiteError**)error
{
    NSString *sql = [self prepareCreateTableSql:classVar];
    [self executeSql:sql error:error];
}
// --- CreateTable - Fine


// --- DropTable
- (void)dropTable:(Class)classVar error:(SQLiteError**)error
{
    NSString *tableName = [self tableName:classVar];
    NSString *sql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", tableName];
    [self executeSql:sql error:error];
}
// --- DropTable - Fine

// --- Insert
- (NSString*)prepareInsertSql:(Class)classVar
{
    NSString *sql = nil;
    
    if([classVar conformsToProtocol:@protocol(SQLiteProtocol)])
    {
        NSMutableArray *sqlFields = [NSMutableArray array];
        NSMutableArray *sqlValues = [NSMutableArray array];
        
        NSArray *classFields = [[classVar alloc] SQLiteFields];
        for (SQLiteField *f in classFields)
        {
            NSString *name = f.name;
            [sqlFields addObject:name];
            [sqlValues addObject:@"?"];
        }
        
        NSString *strSqlFields = [sqlFields componentsJoinedByString:@","];
        NSString *strSqlValues = [sqlValues componentsJoinedByString:@","];
        
        NSString *tableName = [self tableName:classVar];
        
        sql = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)", tableName, strSqlFields, strSqlValues];
    }
    
    return sql;
}
- (void)insert:(NSObject<SQLiteProtocol>*)object error:(SQLiteError**)error;
{
    NSString *sql = [self prepareInsertSql:[object class]];
    [self executeInsertOrUpdate:sql object:object error:error];
}
- (void)insertAll:(NSArray*)arrObject error:(SQLiteError**)error
{
    NSString *sql = nil;
    
    for (NSObject<SQLiteProtocol> *object in arrObject) {
        if(sql == nil) sql = [self prepareInsertSql:[object class]];
        
        [self executeInsertOrUpdate:sql object:object error:error];
    }

}
// --- Insert - Fine

- (void)close
{
    sqlite3_close(self.db);
}

@end

/**
 * SQLiteLib
 */
@implementation SQLiteLib

+ (SQLiteDatabase*)openDatabase:(SQLiteConfig*)config error:(SQLiteError**)error
{
    SQLiteDatabase *sqliteDb = nil;
    *error = NULL;
    
    sqlite3 *database = NULL;
    NSString *filePath = config.pathFile;
    
    if(sqlite3_open([filePath UTF8String], &database) == SQLITE_OK) {
        sqliteDb = [[SQLiteDatabase alloc] init];
        sqliteDb.db = database;
    }
    else
    {
        *error = [SQLiteError createFromDatabase:database];
    }
    
    return sqliteDb;
}

- (BOOL)createTable:(Class)classObject
{
    BOOL success = NO;
    
    
    return success;
}


@end



/**
 * SQLiteFieldExtra
 */
@implementation SQLiteFieldExtra : NSObject

- (SQLiteFieldExtra*)initWithType:(SQLiteFieldExtraType)type params:(NSDictionary *)params
{
    self = [self init];
    self.type = type;
    self.params = params;
    return self;
}

+(SQLiteFieldExtra*)primaryKey
{
    SQLiteFieldExtra *m = [[SQLiteFieldExtra alloc] initWithType:SQLiteFieldExtraTypePrimaryKey params:nil];
    return m;
}
+ (SQLiteFieldExtra*)itemClass:(Class)classVar
{
    SQLiteFieldExtra *m = [[SQLiteFieldExtra alloc] initWithType:SQLiteFieldExtraTypeItemClass params:@{ @"classVar" : classVar }];
    return m;
}

@end



/**
 * SQLiteField
 */
@implementation SQLiteField : NSObject

#pragma mark Converters
+ (NSString*)convertFromDateToStringUTC:(NSDate*)dateInput
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
    NSString *stringFromDate = [formatter stringFromDate:dateInput];
    
    return stringFromDate;
}
+ (NSDate*)convertFromStringUTCToDate:(NSString*)strInput
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
    NSDate *date = [formatter dateFromString:strInput];
    
    return date;
}

- (NSString*)sqliteFieldType
{
    NSString *s = nil;
    
    switch (self.type) {
        case SQLiteFieldTypeBoolean:
            s = @"BOOLEAN";
            break;
        case SQLiteFieldTypeArray:
            break;
        case SQLiteFieldTypeDateTime:
            s = @"TEXT";
            break;
        case SQLiteFieldTypeFloat:
            s = @"FLOAT";
            break;
        case SQLiteFieldTypeInteger:
            s = @"INT";
            break;
        case SQLiteFieldTypeString:
            s = @"TEXT";
            break;
    }
    
    return s;
}

- (void)bindToSqliteStatement:(sqlite3_stmt *)stmt object:(NSObject<SQLiteProtocol>*)object index:(int)index
{
    id value = [object valueForKey:self.name];
    
    switch (self.type) {
        case SQLiteFieldTypeBoolean:
            sqlite3_bind_int(stmt, index, [value intValue]);
            break;
        case SQLiteFieldTypeArray:
            break;
        case SQLiteFieldTypeDateTime:
        {
            NSString *s = [SQLiteField convertFromDateToStringUTC:value];
            sqlite3_bind_text(stmt, index, [s UTF8String], -1, NULL);
        }
            break;
        case SQLiteFieldTypeFloat:
            sqlite3_bind_double(stmt, index, [value floatValue]);
            break;
        case SQLiteFieldTypeInteger:
            sqlite3_bind_int(stmt, index, [value intValue]);
            break;
        case SQLiteFieldTypeString:
            sqlite3_bind_text(stmt, index, [value UTF8String], -1, NULL);
            break;
    }
}

- (SQLiteField*)initWithName:(NSString*)name type:(SQLiteFieldType)type extra:(NSArray*)extra
{
    self = [self init];
    self.name = name;
    self.type = type;
    self.extra = extra;
    return self;
}

+ (SQLiteField*)field:(NSString*)name type:(SQLiteFieldType)type extra:(NSArray*)extra
{
    SQLiteField *m = [[SQLiteField alloc] initWithName:name type:type extra:extra];
    return m;
}
+ (SQLiteField*)field:(NSString*)name type:(SQLiteFieldType)type
{
    return [SQLiteField field:name type:type];
}


- (BOOL)containsExtraType:(SQLiteFieldExtraType)extraType
{
    BOOL retVal = NO;
    
    if(self.extra!=nil)
    {
        for(SQLiteFieldExtra *t in self.extra)
        {
            if(t.type == extraType)
            {
                retVal = YES;
            }
        }
    }
    
    return retVal;
}

+ (SQLiteField*)primaryKeyField:(NSObject*)object
{
    SQLiteField *f = nil;
    
    if([object conformsToProtocol:@protocol(SQLiteProtocol)])
    {
        NSObject<SQLiteProtocol> *obj = (NSObject<SQLiteProtocol>*)object;
        NSArray *sqlFields = [obj SQLiteFields];
        for(SQLiteField *temp in sqlFields)
        {
            if([temp containsExtraType:SQLiteFieldExtraTypePrimaryKey])
            {
                f = temp;
            }
        }
    }
    
    return f;
}

@end


