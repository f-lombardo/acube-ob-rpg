**FREE
ctl-opt DftActGrp(*No) option (*srcstmt : *nodebugio : *nounref);
//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *

 // - - - - - - -
 // Workfields
 // - - - - - - -

 dcl-s WebServiceUrl    varchar(2048) inz;
 dcl-s WebServiceHeader varchar(2048) inz;
 dcl-s WebServiceBody   varchar(2048) inz;
 dcl-s Token            varchar(2048) inz;
 dcl-s Text             varchar(2048)  inz;

 // - - - - - - -

 dcl-ds jsonData   qualified;
        fiscalId   varchar(35);
 end-ds;

//========================================================================*
// External program calls
//------------------------------------------------------------------------*
dcl-pr getenv pointer extproc('getenv');
        *n pointer value options(*string:*trim);
end-pr;

 dcl-pr writeJobLog int(10) extproc('Qp0zLprintf');
   *n pointer value options(*string); // logMsg
   *n pointer value options(*string:*nopass);
   *n pointer value options(*string:*nopass);
   *n pointer value options(*string:*nopass);
   *n pointer value options(*string:*nopass);
   *n pointer value options(*string:*nopass);
   *n pointer value options(*string:*nopass);
   *n pointer value options(*string:*nopass);
   *n pointer value options(*string:*nopass);
   *n pointer value options(*string:*nopass);
   *n pointer value options(*string:*nopass);
 end-pr;

 dcl-c joblogCRLF const(x'0d25');
// Example:
//     writeJobLog ( WebServiceHeader + '%s' : joblogCRLF );
//========================================================================*

 //--------------------------------------------------------

 Exsr SetUp;
 Exsr ConsumeWs;

 *Inlr = *On;
 Return;

 //--------------------------------------------------------
 // SetUp  subroutine
 //--------------------------------------------------------

 Begsr SetUp;
   WebServiceUrl = 'https://ob-sandbox.api.acubeapi.com/' +
                   'business-registry';

   Token = %str(getenv('ACUBE_TOKEN'));

   WebServiceHeader = '<httpHeader> ' +
                      '  <header name="authorization" value="bearer ' + Token + '" /> ' +
                      '  <header name="accept" value="application/json" /> ' +
                      '  <header name="content-type" value="application/json" /> ' +                                              
                      '</httpHeader>';

    Exec SQL
    Declare File Cursor For
        SELECT CAST(LINE AS CHAR(2048))
        From Table(IFS_READ('src/br.json', 2048, 'NONE' )) As IFS;

    Exec SQL Close File;
    Exec SQL Open File;

    Exec SQL Fetch Next From File Into :WebServiceBody;

    Exec SQL Close File; 
 Endsr;

 //--------------------------------------------------------
 // ConsumeWs  subroutine
 //--------------------------------------------------------

 Begsr ConsumeWs;

 Exec sql
   Declare CsrC01 Cursor For
     Select * from
       Json_Table(Systools.HttpPostClob(:WebServiceUrl, :WebServiceHeader,
                                        :WebServiceBody),
       '$'
       Columns(Token VarChar(2048)  Path '$.fiscalId')) As x;

   Exec Sql Close CsrC01;
   Exec Sql Open  CsrC01;

   DoU 1 = 0;
     Exec Sql
         Fetch Next From CsrC01 into :jsonData;

        If SqlCode < *Zeros or SqlCode = 100;

           If SqlCode < *Zeros;
              Exec Sql
                   Get Diagnostics Condition 1
                   :Text = MESSAGE_TEXT;
           EndIf;

           Exec Sql
                Close CsrC01;
           Leave;
        EndIf;

    dsply jsonData.fiscalId;
  Enddo;

 Endsr;

//- - - - - - - - - - - - - - 


