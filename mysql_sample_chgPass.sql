## MySQL 
DROP FUNCTION IF EXISTS sf_pass_chg;
delimiter $$
CREATE FUNCTION sf_pass_change(
	p_st_field1 varchar(50),
	p_st_field2 varchar(10),
    p_st_field3 varchar(10)
) 
RETURNS json DETERMINISTIC
BEGIN
	DECLARE t_st_salt varchar(32); 
	DECLARE t_id_user blob;
    DECLARE t_st_senha blob;
    DECLARE t_success varchar(32); 
    DECLARE t_salt varchar(32);
	SELECT 	id_usuario, st_salt, st_senha 
		INTO 
			t_id_user,t_st_salt, t_st_senha			 
		FROM tb_users
		WHERE st_email = p_st_field1;
        
	IF t_id_user IS null THEN
		RETURN (SELECT json_object("ERROR","Usuario nao encontrado"));
	END IF;
	IF CONVERT(sf_pass_encoder(trim(p_st_field2), t_st_salt), CHAR CHARACTER SET utf8mb4) = t_st_senha THEN 
		SET t_salt = salt_gen();
		UPDATE tb_users SET st_senha = sf_pass_encoder(trim(p_st_field3), t_salt), st_salt = t_salt
			WHERE st_email = p_st_field1;
		SET t_success = "Senha alterada com sucesso";
	ELSE
		SET t_success = "Senha atual incorreta";
	END IF;
	
	RETURN (SELECT json_object("change",t_success));
END; $$
