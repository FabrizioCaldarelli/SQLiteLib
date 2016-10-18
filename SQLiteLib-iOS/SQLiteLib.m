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

- (long)queryScalarLong:(NSString*)sql error:(SQLiteError**)error
{
    long retVal = 0;
    *error = NULL;
    
    const char *sqlStatement = [sql UTF8String];
    sqlite3_stmt *compiledStatement;
    if(sqlite3_prepare_v2(self.db, sqlStatement,-1, &compiledStatement, NULL) == SQLITE_OK)
    {
        if(sqlite3_step(compiledStatement) == SQLITE_ROW)
        {
            retVal = sqlite3_column_int64(compiledStatement, 0);
        }
        else
        {
            *error = [SQLiteError createFromDatabase:self.db];
        }
    }
    else
    {
        *error = [SQLiteError createFromDatabase:self.db];
    }
    sqlite3_finalize(compiledStatement);
    
    return retVal;
}

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
// --- CreateTable - End


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
    [self insertAll:@[ object ] error:error];
}
- (void)insertAll:(NSArray*)arrObject error:(SQLiteError**)error
{
    char *errorMessage;
    
    if(arrObject.count > 0)
    {
        NSObject<SQLiteProtocol> *firstObject = [arrObject firstObject];
        NSString *sql = [self prepareInsertSql:[firstObject class]];
        
        sqlite3_exec(self.db, "BEGIN TRANSACTION", NULL, NULL, &errorMessage);
        
        const char *sqlStatement = [sql UTF8String];
        sqlite3_stmt *stmt;
        if(sqlite3_prepare_v2(self.db, sqlStatement,-1, &stmt, NULL) == SQLITE_OK)
        {
            for (NSObject<SQLiteProtocol> *object in arrObject) {
                
                NSArray *classFields = [object SQLiteFields];
                for(int k=0;k<classFields.count;k++)
                {
                    SQLiteField *f = [classFields objectAtIndex:k];
                    [f bindToSqliteStatement:stmt object:object index:(k+1)];
                }
                
                if(sqlite3_step(stmt) != SQLITE_DONE)
                {
                    *error = [SQLiteError createFromDatabase:self.db];
                }
                sqlite3_reset(stmt);
            }
            sqlite3_exec(self.db, "COMMIT TRANSACTION", NULL, NULL, &errorMessage);
            sqlite3_finalize(stmt);
        }
        else
        {
            *error = [SQLiteError createFromDatabase:self.db];
        }
    }
}
// --- Insert - End


// --- Select
- (NSArray*)selectList:(Class)classVar sql:(NSString*)sql error:(SQLiteError**)error
{
    *error = NULL;
    
    NSMutableArray *listOut = [NSMutableArray array];
    
    const char *sqlStatement = [sql UTF8String];
    sqlite3_stmt *compiledStatement;
    if(sqlite3_prepare_v2(self.db, sqlStatement,-1, &compiledStatement, NULL) == SQLITE_OK)
    {
        // StatementsColumn
        NSMutableArray *stmtColumns = [NSMutableArray array];
        for(int kCol=0;kCol<sqlite3_column_count(compiledStatement);kCol++)
        {
            NSString *cn = [NSString stringWithUTF8String:(char *) sqlite3_column_name(compiledStatement, kCol)];
            [stmtColumns addObject:cn];
        }
        
        while(sqlite3_step(compiledStatement) == SQLITE_ROW) {
            
            id<SQLiteProtocol> object = [[classVar alloc] init];
            NSArray *classFields = [object SQLiteFields];
            for(int k=0;k<classFields.count;k++)
            {
                SQLiteField *f = [classFields objectAtIndex:k];
                [f valueFromSqliteStatement:compiledStatement object:object index:k stmtColumns:stmtColumns];
            }
            [listOut addObject:object];
        }
        
        
        if(sqlite3_step(compiledStatement) != SQLITE_DONE)
        {
            *error = [SQLiteError createFromDatabase:self.db];
        }
        else
        {
            sqlite3_finalize(compiledStatement);
        }
    }
    else
    {
        *error = [SQLiteError createFromDatabase:self.db];
    }
    
    return [NSArray arrayWithArray:listOut];
}
// --- Select - End

// --- Distance Gps Function
#define DEG2RAD(degrees) (degrees * 0.01745327) // degrees * pi over 180
static void SQLite_distanceGPSFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{
    // check that we have four arguments (lat1, lon1, lat2, lon2)
    assert(argc == 4);
    // check that all four arguments are non-null
    if (sqlite3_value_type(argv[0]) == SQLITE_NULL || sqlite3_value_type(argv[1]) == SQLITE_NULL || sqlite3_value_type(argv[2]) == SQLITE_NULL || sqlite3_value_type(argv[3]) == SQLITE_NULL) {
        sqlite3_result_null(context);
        return;
    }
    // get the four argument values
    double lat1 = sqlite3_value_double(argv[0]);
    double lon1 = sqlite3_value_double(argv[1]);
    double lat2 = sqlite3_value_double(argv[2]);
    double lon2 = sqlite3_value_double(argv[3]);
    // convert lat1 and lat2 into radians now, to avoid doing it twice below
    double lat1rad = DEG2RAD(lat1);
    double lat2rad = DEG2RAD(lat2);
    // apply the spherical law of cosines to our latitudes and longitudes, and set the result appropriately
    // 6378.1 is the approximate radius of the earth in kilometres
    sqlite3_result_double(context, acos(sin(lat1rad) * sin(lat2rad) + cos(lat1rad) * cos(lat2rad) * cos(DEG2RAD(lon2) - DEG2RAD(lon1))) * 6378.1);
}

- (void)addGpsDistanceFunction:(NSString*)functionName
{
    sqlite3_create_function(self.db, [functionName UTF8String], 4, SQLITE_UTF8, NULL, &SQLite_distanceGPSFunc, NULL, NULL);
}
// --- Distance Gps - End

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

- (void)valueFromSqliteStatement:(sqlite3_stmt *)stmt object:(NSObject<SQLiteProtocol>*)object index:(int)index stmtColumns:(NSArray*)stmtColumns
{
    BOOL foundColumn = NO;
    if(index<stmtColumns.count)
    {
        NSString *cn = [stmtColumns objectAtIndex:index];
        if([cn isEqualToString:self.name]) foundColumn = YES;
    }
    
    int curIndex = index;
    
    if(foundColumn == NO)
    {
        curIndex = -1;
        
        int k = 0;
        while((foundColumn == NO)&&(k<stmtColumns.count))
        {
            NSString *cn = [stmtColumns objectAtIndex:k];
            if([cn isEqualToString:self.name])
            {
                foundColumn = YES;
            }
            else
            {
                k++;
            }
        }
        if(foundColumn) curIndex = k;
    }
    
    if(curIndex>=0)
    {
        switch (self.type) {
            case SQLiteFieldTypeBoolean:
                [object setValue:[NSNumber numberWithInt:sqlite3_column_int(stmt, curIndex)] forKey:self.name];
                break;
            case SQLiteFieldTypeArray:
                break;
            case SQLiteFieldTypeDateTime:
            {
                char *chs = (char *) sqlite3_column_text(stmt, curIndex);
                NSString *s = (chs!=NULL)?[NSString stringWithUTF8String:(char *) sqlite3_column_text(stmt, curIndex)]:nil;
                NSDate *d = nil;
                if(s!=nil) d = [SQLiteField convertFromStringUTCToDate:s];
                [object setValue:d forKey:self.name];
            }
                break;
            case SQLiteFieldTypeFloat:
                [object setValue:[NSNumber numberWithFloat:sqlite3_column_double(stmt, curIndex)] forKey:self.name];
                break;
            case SQLiteFieldTypeInteger:
                [object setValue:[NSNumber numberWithInt:sqlite3_column_int(stmt, curIndex)] forKey:self.name];
                break;
            case SQLiteFieldTypeString:
            {
                char *chs = (char *) sqlite3_column_text(stmt, curIndex);
                NSString *s = (chs!=NULL)?[NSString stringWithUTF8String:(char *) sqlite3_column_text(stmt, curIndex)]:nil;
                [object setValue:s forKey:self.name];
            }
                break;
        }
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
    return [SQLiteField field:name type:type extra:nil];
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


