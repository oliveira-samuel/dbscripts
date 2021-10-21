### PostgreSQL
CREATE OR REPLACE FUNCTION financial.sf_entries_insert(
	p_dt_field1 date,
	p_id_field2 uuid,
	p_si_filed3 smallint,
	p_st_filed4 character varying,
	p_js_field5 json,
	p_in_field6 integer,
	p_id_field7 uuid,
	p_id_field8 uuid,
	OUT id_field1out uuid,
	OUT dt_field2out date,
	OUT js_field3out json,
	OUT js_field4out json,
	OUT js_field5out json,
	OUT st_field6out character varying,
	OUT js_field7out json,
	OUT js_field8out json,
	OUT js_field9out json,
	OUT js_field10out json,
	OUT js_field11out json,
	OUT id_field12out uuid,
	OUT ts_field13out timestamp without time zone
) RETURNS record
AS $$
DECLARE 
	t_entry record;
	t_entry_first record;
	t_fund_transaction record;
	t_re_value real;
	t_si_entry_type smallint;
	t_re_current_cash real;
	t_fiscal_year record;
	t_re_accumulated real;
	t_in_couter integer;
	t_dt_recurring date;
	t_si_recurring_year smallint;
	t_id_fiscal_year_recurring uuid;
BEGIN
	SELECT INTO t_fiscal_year * FROM accounting.tb_fcl_year
		WHERE id_field7 = p_id_field7
			AND ts_end IS NULL
			AND si_year = extract(year from p_dt_field1);
	IF (p_dt_field1<t_fiscal_year.ts_begin) 
			OR (extract(year from p_dt_field1) > extract(year from CURRENT_DATE) + 1) THEN
		RAISE EXCEPTION 'invalid_fiscal_year' USING ERRCODE = 23000, HINT = 'Fiscal year not available';
	END IF;		
	t_re_value = (p_js_field5->>'value')::real;
	SELECT INTO t_si_entry_type acc.si_classification 
		FROM financial.tb_account acc 
			WHERE id_field2 = p_id_field2;
	t_re_value = (p_js_field5->>'value')::real;
	IF  t_si_entry_type = 0 THEN
		IF (t_re_value < 1) THEN 
			t_re_value = t_re_value * -1;
		END IF;
	ELSEIF t_si_entry_type = 1 THEN
		IF (t_re_value > 1) THEN 
			t_re_value = t_re_value * -1;
		END IF;
	END IF;	
	t_dt_recurring = p_dt_field1;
	p_in_field6 = p_in_field6 + 1;
	FOR t_in_couter IN 1..p_in_field6 LOOP
		SELECT INTO t_si_recurring_year extract(year from t_dt_recurring);
		SELECT INTO t_id_fiscal_year_recurring fiy.id_fiscal_year FROM accounting.tb_fcl_year fiy 
			WHERE fiy.si_year = t_si_recurring_year AND fiy.id_field7 = p_id_field7;
		IF t_id_fiscal_year_recurring IS null THEN
			RAISE EXCEPTION 'invalid_fiscal_year' USING ERRCODE = 23000, HINT = 'Fiscal year ' || t_si_recurring_year::text || ' not opened.';
		END IF;
		INSERT INTO financial.tb_entries(
			id_field8, 
			id_field7, 
			dt_field1, 
			id_field2, 
			id_fiscal_year, 
			st_filed4, 
			re_price, 
			si_currency,
			id_parent,
			si_filed3
		) VALUES (		
			p_id_field8, 
			p_id_field7, 
			t_dt_recurring, 
			p_id_field2, 
			t_id_fiscal_year_recurring, 
			p_st_filed4,
			t_re_value, 
			(p_js_field5->>'currency')::smallint,
			null,
			p_si_filed3
		) RETURNING
			tb_entries.id_etry,
			tb_entries.id_field8,
			tb_entries.id_field7,
			tb_entries.ts_created,
			tb_entries.ts_updated,
			tb_entries.id_transaction_hash,
			tb_entries.dt_field1,
			tb_entries.id_field2,
			tb_entries.id_fiscal_year,
			tb_entries.st_filed4,
			tb_entries.si_filed3,
			tb_entries.re_price,
			tb_entries.si_currency,
			tb_entries.id_fund_transaction,
			tb_entries.id_parent
		INTO t_entry;
		IF t_in_couter = 1 THEN
			t_entry_first = t_entry;
		END IF;
	
		id_etry = t_entry.id_etry;
		dt_field1 = t_entry.dt_field1;
		IF (t_entry.id_field2 IS NOT null) THEN
			SELECT INTO js_field2out json_build_object('id',acc.id_field2,'code',acc.st_code,'name',acc.st_name,
					'classification', json_build_object('id',cls.si_classification::text,'name',cls.st_name)) 
				  FROM financial.tb_account acc
					INNER JOIN accounting.tb_classification cls ON cls.si_classification = acc.si_classification 
						AND acc.id_field2 = t_entry.id_field2;
		END IF;
		SELECT INTO js_fiscal_year json_build_object('id',fiy.id_fiscal_year,'year',fiy.si_year,'ended',
			(CASE WHEN (fiy.ts_end IS NOT NULL) THEN 
				CASE WHEN (t_entry.dt_field1 BETWEEN fiy.ts_begin::date AND fiy.ts_end::date) THEN 
					true
				ELSE
					false
				END
			 ELSE 
				CASE WHEN (t_entry.dt_field1 < fiy.ts_begin::date OR EXTRACT(year from t_entry.dt_field1) > fiy.si_year) THEN 
					false
				ELSE
					true
				END
			 END)) 
			FROM accounting.tb_fcl_year fiy 
				WHERE fiy.id_fiscal_year = t_entry.id_fiscal_year;
		SELECT INTO js_category json_build_object('id',ctg.si_filed3,'name',ctg.st_name) FROM financial.tb_entries_category ctg WHERE ctg.si_filed3 = t_entry.si_filed3;			
		st_filed4 = t_entry.st_filed4;
		SELECT INTO js_field5 json_build_object('value',t_entry.re_price,
			'current',(SELECT json_build_object('id',cur.si_currency::text,'symbol',cur.st_symbol,'name',cur.st_name) 
				FROM base.tb_currency cur 
					WHERE cur.si_currency = t_entry.si_currency));
		SELECT INTO js_bordereau json_build_object(
				'card-credit', 
					(SELECT json_build_object('card-network',json_build_object('id',ntw.si_card_network,'name',ntw.st_name),
						'card-acquirer',(SELECT json_build_object('id',acq.si_card_acquirer,'name',acq.st_name)
							FROM base.tb_card_acquirer acq WHERE acq.si_card_acquirer = brd.si_card_acquirer)) 
					 FROM base.tb_card_network ntw WHERE ntw.si_card_network = brd.si_card_network)
					)
			FROM financial.tb_bordereau_credit_card brd
				WHERE brd.id_etry = t_entry.id_etry;				
		SELECT INTO js_cash json_build_object('value',fiy.js_data->'cash'->'current','currency',
			(SELECT json_build_object('id',cur.si_currency::text,'symbol',cur.st_symbol,'name',cur.st_name) 
				FROM base.tb_currency cur 
					WHERE cur.si_currency = fiy.si_currency)) 
			FROM accounting.tb_fcl_year fiy 
				WHERE fiy.id_fiscal_year = t_entry.id_fiscal_year;	
		SELECT INTO js_population json_build_object('id',rlm.id_field7,'label',rlm.st_label) 
			FROM core.tb_population rlm 
				WHERE rlm.id_field7 = t_entry.id_field7;
		SELECT INTO js_auth json_build_object('id',usr.id_user,'username',usr.st_username) 
			FROM core.tb_user usr 
				WHERE usr.id_user = t_entry.id_field8;
		id_transaction_hash = t_entry.id_transaction_hash;
		ts_created = t_entry.ts_created;
		INSERT INTO financial.ftb_entries(
			entry,date_entry,account,fiscal_year,history,price,population,auth,transaction_hash,created,reconciliation)
		VALUES (
			id_etry,dt_field1,js_field2out,js_fiscal_year,st_filed4,js_field5,js_population,js_auth,id_transaction_hash,ts_created,'{}'::json);
		t_dt_recurring = t_dt_recurring + interval '1 month';
	END LOOP;
	FOR t_fiscal_year IN (SELECT * FROM accounting.tb_fcl_year WHERE id_field7 = p_id_field7 AND si_year >= extract(year from p_dt_field1))
	LOOP
		PERFORM amqp.publish(1, 'postgresql', 'financial.tb_entries.insert',json_build_object('population',t_fiscal_year.id_field7,'fiscal-year',t_fiscal_year.id_fiscal_year)::text);
	END LOOP;
END;
$$ LANGUAGE 'plpgsql';
