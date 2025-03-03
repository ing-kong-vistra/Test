set sqlblanklines on
CREATE OR REPLACE PACKAGE        "IA_ZIPCODE_IMPORT_PG" IS
--;*****************************************************************************
--;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
--;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
--;!!!!!!!                                                             !!!!!!!!!
--;!!!!!!!            This program is the sole property of:            !!!!!!!!!
--;!!!!!!!                                                             !!!!!!!!!
--;!!!!!!!                     PHOENIX LEASING INC.                    !!!!!!!!! 
--;!!!!!!!                       San Rafael, CA.                       !!!!!!!!!
--;!!!!!!!                                                             !!!!!!!!!
--;!!!!!!! and may not be copied in whole or in part without expressed !!!!!!!!!
--;!!!!!!!        written permission from Phoenix Leasing, Inc.        !!!!!!!!!
--;!!!!!!!                                                             !!!!!!!!!
--;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
--;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
--;*****************************************************************************
--;
--;	PURPOSE: 	Load Zip Code
--;
--;	DETAIL
--;	DESCRIPTION:	
--;
--;	SPECIAL NOTES:	
--;
--;	DATE:			06-Mar-2015
--;
--;	PROGRAMMER: 	Ing
--;
--;*****************************************************************************
--;
--;                            MODIFICATION HISTORY
--;
--;*****************************************************************************
--;
--; TASK/CAR#    DATE       WHO  DESCRIPTION
--;  ------   -----------   ---  -----------------------------------------------
--;   21930   09-Mar-2015   IngK   Fix Zipcode program
--;*****************************************************************************
--;*****************************************************************************

procedure MAIN(	arg_PROCESS_SEQ in number, ARG_SEND_EMAIL_TO in VARCHAR2 DEFAULT NULL);

TYPE T_SPLIT_TABLE IS TABLE OF VARCHAR2(100) INDEX BY BINARY_INTEGER; 

--==============================================================================
FUNCTION SPLIT_fn
--==============================================================================
 (p_in_string in VARCHAR2, p_delimiter in VARCHAR2) 
RETURN T_SPLIT_TABLE;

end IA_ZIPCODE_IMPORT_PG;
/


CREATE OR REPLACE PACKAGE BODY        "IA_ZIPCODE_IMPORT_PG" is

izipcode                        Number(2);
istate                          Number(2);
icity                           Number(2);
icounty                         Number(2);


T_COUNT                         Number(5);
Prev_ZipCode                    VARCHAR2(15);

T_MSG                           VARCHAR2(150);

Zipcodes                        T_SPLIT_TABLE;

-- Cursor Declarations ------------------
cursor INPUT_FILE_QRY is
  select * from WRK_IA_FILE_IMPORT_TEMP  
  order by RECORD_SEQ;

INPUT_FILE_BUF				INPUT_FILE_QRY%rowtype;

-------------------------------------------------------------------------


-- Functions and Procedures -------------
-----------------------------------------
procedure MAIN(	arg_PROCESS_SEQ in number, ARG_SEND_EMAIL_TO in VARCHAR2 DEFAULT NULL) is

begin

  izipcode := 0+1;
  istate   := 22+1;
  icity    := 27+1;
  icounty  := 29+1;

  Prev_ZipCode := '';

  BEGIN EXECUTE IMMEDIATE 'TRUNCATE TABLE  WRK_IA_ZIP_CODE_TABLE'; EXCEPTION WHEN OTHERS THEN NULL; END;

-------------------------------------------------------------------------------------
-- import zip code into temp table
-------------------------------------------------------------------------------------
open INPUT_FILE_QRY;
fetch INPUT_FILE_QRY into INPUT_FILE_BUF;

if INPUT_FILE_QRY%NOTFOUND then
  raise_application_error (-20000, 'Empty ZipCode Import file');
end if;
     
while INPUT_FILE_QRY%found AND LENGTH(TRIM(INPUT_FILE_BUF.RECORD_DATA))>20 loop

	begin 
                Zipcodes := SPLIT_fn(INPUT_FILE_BUF.RECORD_DATA, ',');
                
                IF (Upper(Zipcodes(izipcode)) <> 'ZIPCODE' AND Prev_ZipCode <> Zipcodes(izipcode)) THEN

                    Insert Into WRK_IA_ZIP_CODE_TABLE(ZIP_CODE, CITY, STATE, COUNTY_NAME, LOADED_ON, LOADED_BY)
                    Values(Zipcodes(izipcode),Zipcodes(icity), Zipcodes(istate),Zipcodes(icounty), sysdate, 'PHXA');

                END IF;		
		
                Prev_ZipCode := Zipcodes(izipcode);

  		exception when others then	
			raise_application_error(-20000, sqlerrm||' - record: '||INPUT_FILE_BUF.RECORD_DATA);
	end;
	
	fetch INPUT_FILE_QRY into INPUT_FILE_BUF;
end loop;
	
close INPUT_FILE_QRY;	

BEGIN EXECUTE IMMEDIATE 'TRUNCATE TABLE  IA_ZIP_CODE_TABLE'; EXCEPTION WHEN OTHERS THEN NULL; END;

INSERT INTO IA_ZIP_CODE_TABLE SELECT ZIP_CODE, CITY, STATE, COUNTY_NAME, sysdate, 'PHXA' FROM WRK_IA_ZIP_CODE_TABLE
       GROUP BY ZIP_CODE, CITY, STATE, COUNTY_NAME;

commit;

 IF ARG_SEND_EMAIL_TO IS NOT NULL THEN

    SELECT COUNT(*) INTO T_COUNT FROM IA_ZIP_CODE_TABLE;

    T_MSG := 'Total records imported: '|| TO_CHAR(T_COUNT);

    IA_GLOBAL_PG.IA_SEND_EMAIL_SP(
    			arg_FROM        => 'helpdesk@phxa.com',
			arg_TO          =>  ARG_SEND_EMAIL_TO,
			arg_SUBJECT     => 'Zip Code Import Alert',
			arg_MESSAGE     => T_MSG,
			arg_APPEND_ENV  => 'Y');

 END IF;

exception when others then
	if INPUT_FILE_QRY%isopen then
		close INPUT_FILE_QRY;
	end if;
	rollback;
	raise;
end;

-----------------------------------------
FUNCTION SPLIT_fn
	(p_in_string in VARCHAR2, p_delimiter in VARCHAR2) RETURN T_SPLIT_TABLE is

i       number := 0; 
pos     number := 0; 
lv_str  varchar2(2000) := p_in_string; 
       
strings T_SPLIT_TABLE; 
    
BEGIN 

  lv_str := Replace(lv_str, '"','');

  --IA_GLOBAL_PG.WRITE_IA_TEST('p_in_string:'||p_in_string);
  --IA_GLOBAL_PG.WRITE_IA_TEST('p_delimiter:'||p_delimiter);
    
  pos := instr(lv_str,p_delimiter,1,1); 

  IF (pos = 0 AND NVL(lv_str, ' ') <> ' ') THEN
      strings(1) := lv_str;
  ELSE 

      WHILE ( pos != 0) LOOP 

	 -- increment counter  
	 i := i + 1; 

	 -- create array element for chuck of string  
	 strings(i) := substr(lv_str,1,pos-1); 
        -- IA_GLOBAL_PG.WRITE_IA_TEST('lv_str:'||substr(lv_str,1,pos-1));

	 -- remove chunk from string  
	 lv_str := substr(lv_str,pos+1,length(lv_str)); 

	 -- determine next chunk  
	 pos := instr(lv_str,p_delimiter,1,1); 

	 -- no last chunk, add to array  
	 IF pos = 0 THEN 

		strings(i+1) := lv_str; 

	 END IF; 



      END LOOP; 

  END IF;

-- return array  
RETURN strings; 

END SPLIT_fn; 

end IA_ZIPCODE_IMPORT_PG;
/
