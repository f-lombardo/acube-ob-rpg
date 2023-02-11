**FREE
ctl-opt DftActGrp(*No) option (*srcstmt : *nodebugio : *nounref);
// ==================================================================================
// In order to compile this program run:
// CRTSQLRPGI OBJ(CREATEBR) SRCSTMF('/path/to/your/src/createbr.rpgle')
// Before running the program add environment variable containing the path of the file
// with the JSON payload
// ADDENVVAR ENVVAR(ACUBE_IFS_JSON) VALUE('/path/to/your/src/input.json')
// ==================================================================================

// ==================================================================================
// Variables
// ==================================================================================
dcl-s WebServiceUrl    varchar(2048) inz;
dcl-s WebServiceHeader varchar(2048) inz;
dcl-s WebServiceBody   varchar(2048) inz;
dcl-s Token            varchar(2048) inz;
dcl-s JsonInputFile    varchar(128)  inz;
dcl-s Text             varchar(2048) inz;

// A ds that will contain data from JSON response
dcl-ds jsonData   qualified;
  fiscalId   varchar(35);
end-ds;

// ==================================================================================
// External utilities
// ==================================================================================
dcl-pr getenv pointer extproc('getenv');
  *n pointer value options(*string:*trim);
end-pr;

dcl-pr putenv int(10) extproc('putenv');
  *n pointer value options(*string:*trim) ;
end-pr;

// ==================================================================================
//                             Main program
// ==================================================================================

// ================ SetUp  vars
WebServiceUrl = 'https://ob-sandbox.api.acubeapi.com/' +
               'business-registry';

Token = %str(getenv('ACUBE_TOKEN'));

WebServiceHeader = '<httpHeader> ' +
                  '  <header name="authorization" value="bearer ' + Token + '" /> ' +
                  '  <header name="accept" value="application/json" /> ' +
                  '  <header name="content-type" value="application/json" /> ' +
                  '</httpHeader>';

// ================ Read JSON payload from IFS
JsonInputFile = %str(getenv('ACUBE_IFS_JSON'));

Exec SQL
Declare File Cursor For
    SELECT CAST(LINE AS CHAR(2048))
    From Table(IFS_READ(:JsonInputFile, 2048, 'NONE' )) As IFS;

Exec SQL Open File;

Exec SQL Fetch Next From File Into :WebServiceBody;

Exec SQL Close File;

// ================ Consume Web service
Exec sql
Declare Csr01 Cursor For
 Select * from
   Json_Table(Systools.HttpPostClob(:WebServiceUrl, :WebServiceHeader,
                                    :WebServiceBody),
   '$'
   Columns(FiscalId VarChar(2048)  Path '$.fiscalId')) As x;

Exec Sql Open  Csr01;

DoU 1 = 0;
  Exec Sql
         Fetch Next From Csr01 into :jsonData;

  If SqlCode < *Zeros or SqlCode = 100;

    If SqlCode < *Zeros;
      Exec Sql
                   Get Diagnostics Condition 1
                   :Text = MESSAGE_TEXT;
      SND-MSG 'Error: ' + Text %target(*caller : 1);
    EndIf;

    Exec Sql
                Close Csr01;
    Leave;
  EndIf;

  putenv('ACUBE_FISCALID=' + jsonData.fiscalId) ;
  SND-MSG 'New business registry: ' + jsonData.fiscalId  %target(*caller : 1);
Enddo;

// ================ Exit
*Inlr = *On;
Return;
// ==================================================================================
