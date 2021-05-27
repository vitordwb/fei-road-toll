--****************************
-- CENTRO UNIVERSITARIO FEI
-- Sistemas Digitais II  -  Projeto 2  - 1° Semestre de 2021
-- Componente VHDL: Unidade de Controle do Sisttema de Pedágio => UC.vhd
-- Rev. 0
-- Especificações: entradas: CK, RT, IC, DC, RP, PP, MO, ZR, PO, NG, ES, FT
-- Saidas: Sel_mxa[2..0], Sel_mxb[2..0], Sel_ula[1..0],Lda, Ldb, Ldc,IT
-- Saidas externas: MFC, MEV, LDM
--****************************

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_unsigned.ALL;

ENTITY UC IS
	PORT (
		CK : IN STD_LOGIC; -- clock de 50MHz
		RT : IN STD_LOGIC; -- reinicio total -> ativo em zero
		-- Entradas Externas:
		IC : IN STD_LOGIC; -- incrementa credito -> ativo em um
		DC : IN STD_LOGIC; -- decrementa credito -> ativo em um
		RP : IN STD_LOGIC; -- reinicio parcial -> ativo em um
		PP : IN STD_LOGIC; -- passagem pelo portico -> ativo em um
		MO : IN STD_LOGIC; -- modo de operação -> 1= Normal, 0= Ajusta Valor
		-- Sinais de Estado da ULA:
		ZR : IN STD_LOGIC; -- resultado zero na operação da ULA
		PO : IN STD_LOGIC; -- resultado positivo na operação da ULA
		NG : IN STD_LOGIC; -- resultado negativo na operação da ULA
		ES : IN STD_LOGIC; -- resultado da operação da ULA maior que 255
		-- Sinais de Estado do TIMER:
		FT : IN STD_LOGIC; -- fim da temporização de 1 segundo
		-- Sinais de Saida para MUX:
		Sel_mxa : OUT STD_LOGIC_VECTOR(2 DOWNTO 0); -- seleciona entrada de MUX_A
		Sel_mxb : OUT STD_LOGIC_VECTOR(2 DOWNTO 0); -- seleciona entrada de MUX_B
		-- Sinais de Saida para ULA:
		Sel_ula : OUT STD_LOGIC_VECTOR(1 DOWNTO 0); -- seleciona operação da ULA
		-- Sinais de Saida para Registradores:
		Lda : OUT STD_LOGIC; -- carrega RA
		Ldb : OUT STD_LOGIC; -- carrega RB
		Ldc : OUT STD_LOGIC; -- carrega RC
		-- Sinais de Saida para TIMER:
		IT : OUT STD_LOGIC; -- inicia temporização
		-- Sinais de Saida Externos:
		MEV : OUT STD_LOGIC; -- sinaliza multa por excesso de velocidade 
		MFC : OUT STD_LOGIC; -- sinaliza multa por falta de crédito
		SDM : OUT STD_LOGIC -- sinaliza limite de distância total percorrida 
	);
END UC;
----------------------------------------------------------------------------------
ARCHITECTURE FSM OF UC IS
	TYPE ESTADOS_ME IS (
		ZER_RG -- zera registrador
		, CAR_CR -- carrega credito
		, AJU_CR -- ajusta credito
		, INC_CR -- incrementa credito
		, VER_CRM -- verifica crm
		, MAX_CR -- max valor de cr
		, DEC_CR -- decrementa cr
		, MIN_CR -- minimo valor de cr
		, INC_DP -- incrementa dp
		, INC_DP2 -- incrementa dp segundo estado
		, VER_DT -- verifica dt
		, VER_CR -- verifica cr
		, SIN_LIM -- sinaliza limite
		, MUL_CR -- multa credito
		, VF15 -- espera pp ou dispara timer
		, VF16 -- reinicia dp e reinicia mev
		, REI_DP -- reinicia dp
		, REI_MEV -- reinicia mev
		, VER_VEL -- verifica velocidade
		, MUL_VEL -- multa velocidade

	);
	SIGNAL E : ESTADOS_ME;
BEGIN
	PROCESS (CK, RT)
	BEGIN
		IF RT = '0' THEN
			E <= ZER_RG; -- zera registros
			MFC <= '0';
			MEV <= '0';
			SDM <= '0'; -- zera multas	e sinalização 		
		ELSIF (CK'event AND CK = '1') THEN
			CASE E IS
				WHEN ZER_RG =>
					E <= CAR_CR; -- carrega CR com credito inicial
				WHEN CAR_CR =>
					E <= AJU_CR; --- espera IC e DC com MO=0 para ajustar CR
				WHEN AJU_CR =>
					IF MO = '1' AND PP = '1' THEN
						E <= INC_DP; -- incrementa distancia parcial
					ELSIF MO = '0' AND IC = '1' AND DC = '1' THEN
						E <= INC_CR;
					ELSIF MO = '0' AND IC = '0' AND DC = '1' THEN
						E <= DEC_CR;
					ELSIF PO = '0' THEN
						E <= VER_CRM;
					ELSIF MO = '0' AND IC = '0' AND DC = '0' THEN
						E <= AJU_CR;
					END IF;
				WHEN INC_CR =>
					E <= VER_CRM;
				WHEN VER_CRM =>
					IF PO = '1' THEN
						E <= MAX_CR;
					END IF;
				WHEN MAX_CR => E <= AJU_CR;
				WHEN DEC_CR =>
					IF NG = '0' THEN
						E <= AJU_CR;
					ELSIF NG = '1' THEN
						E <= MIN_CR;
					END IF;
				WHEN MIN_CR =>
					E <= AJU_CR;
				WHEN INC_DP =>
					E <= INC_DP2;
				WHEN INC_DP2 =>
					E <= VER_DT;
				WHEN VER_DT =>
					IF PO = '1' THEN
						E <= SIN_LIM;
					ELSIF PO = '0' THEN
						E <= VER_CR;
					END IF;
				WHEN SIN_LIM =>
					E <= VER_CR;
				WHEN VER_CR =>
					IF NG = '1' THEN
						E <= MUL_CR;
					ELSIF NG = '0' THEN
						E <= VF15;
					END IF;
				WHEN VF15 =>
					IF PP = '0' AND RP = '0' THEN
						E <= VF15;
					ELSIF RP = '1' AND PP = '0' THEN
						E <= VF16;
					ELSIF PP = '1' THEN
						E <= VER_VEL;
					END IF;
				WHEN VF16 =>
					E <= VF15;
				WHEN VER_VEL =>
					IF FT = '0' THEN
						E <= MUL_VEL;
					ELSIF FT = '1' THEN
						E <= INC_DP;
					END IF;

				WHEN OTHERS => NULL;
			END CASE;
		END IF;
	END PROCESS;

	-- Atualização das Saídas para Fluxo de Dados (Multiplexadores, Registradores, ULA)
	PROCESS (E)
	BEGIN
		CASE E IS
			WHEN ZER_RG => -- zera registros
				Sel_mxa <= "XXX";
				Sel_mxb <= "011";
				Sel_ula <= "00";
				Ldc <= '1';
				Ldb <= '1';
				Lda <= '1';
				IT <= '1';
			WHEN CAR_CR => -- carrega CR com Credito Inicial
				Sel_mxa <= "XXX";
				Sel_mxb <= "101";
				Sel_ula <= "00";
				Ldc <= '0';
				Ldb <= '0';
				Lda <= '1';
				IT <= '1';
			WHEN AJU_CR => -- espera IC e DC para ajustar CR
				Sel_mxa <= "XXX";
				Sel_mxb <= "XXX";
				Sel_ula <= "XX";
				Ldc <= '0';
				Ldb <= '0';
				Lda <= '0';
				IT <= '1';
			WHEN INC_CR => -- incrementa CR
				Sel_mxa <= "001";
				Sel_mxb <= "000";
				Sel_ula <= "10";
				Ldc <= '0';
				Ldb <= '0';
				Lda <= '1';
				IT <= '1';
			WHEN VER_CRM => -- verifica CRM
				Sel_mxa <= "101";
				Sel_mxb <= "000";
				Sel_ula <= "11";
				Ldc <= '0';
				Ldb <= '0';
				Lda <= '0';
				IT <= '1';
			WHEN MAX_CR => -- maximo valor de CR
				Sel_mxa <= "XXX";
				Sel_mxb <= "101";
				Sel_ula <= "00";
				Ldc <= '0';
				Ldb <= '0';
				Lda <= '1';
				IT <= '1';
			WHEN DEC_CR => -- decrementa CR
				Sel_mxa <= "001";
				Sel_mxb <= "000";
				Sel_ula <= "11";
				Ldc <= '0';
				Ldb <= '0';
				Lda <= '1';
				IT <= '1';
			WHEN MIN_CR => -- minimo valor CR
				Sel_mxa <= "XXX";
				Sel_mxb <= "111";
				Sel_ula <= "00";
				Ldc <= '0';
				Ldb <= '0';
				Lda <= '1';
				IT <= '1';
			WHEN INC_DP => -- incrementa DP
				Sel_mxa <= "000";
				Sel_mxb <= "001";
				Sel_ula <= "10";
				Ldc <= '0';
				Ldb <= '1';
				Lda <= '0';
				IT <= '1';
			WHEN INC_DP2 => -- incrementa DP
				Sel_mxa <= "000";
				Sel_mxb <= "001";
				Sel_ula <= "10";
				Ldc <= '0';
				Ldb <= '1';
				Lda <= '0';
				IT <= '1';
			WHEN VER_DT => -- verifica DT
				Sel_mxa <= "111";
				Sel_mxb <= "010";
				Sel_ula <= "11";
				Ldc <= '0';
				Ldb <= '0';
				Lda <= '0';
				IT <= '1';
			WHEN SIN_LIM => -- sinaliza limite
				Sel_mxa <= "XXX";
				Sel_mxb <= "XXX";
				Sel_ula <= "XX";
				Ldc <= '0';
				Ldb <= '0';
				Lda <= '0';
				IT <= '1';
			WHEN VER_CR => -- verifica CR
				Sel_mxa <= "101";
				Sel_mxb <= "000";
				Sel_ula <= "11";
				Ldc <= '0';
				Ldb <= '0';
				Lda <= '0';
				IT <= '1';
			WHEN MUL_CR => -- multa CR
				Sel_mxa <= "XXX";
				Sel_mxb <= "111";
				Sel_ula <= "00";
				Ldc <= '0';
				Ldb <= '0';
				Lda <= '0';
				IT <= '1';
			WHEN VF15 => -- espera PP ou RP e dispara timer
				Sel_mxa <= "XXX";
				Sel_mxb <= "XXX";
				Sel_ula <= "XX";
				Ldc <= '0';
				Ldb <= '0';
				Lda <= '0';
				IT <= '0';
			WHEN VF16 => -- reinicia DP e MEV
				Sel_mxa <= "XXX";
				Sel_mxb <= "111";
				Sel_ula <= "00";
				Ldc <= '0';
				Ldb <= '1';
				Lda <= '0';
				IT <= '0';
			WHEN VER_VEL => -- verifica velocidade
				Sel_mxa <= "XXX";
				Sel_mxb <= "XXX";
				Sel_ula <= "XX";
				Ldc <= '0';
				Ldb <= '0';
				Lda <= '0';
				IT <= '0';
			WHEN MUL_VEL => -- incrementa DP
				Sel_mxa <= "XXX";
				Sel_mxb <= "011";
				Sel_ula <= "00";
				Ldc <= '0';
				Ldb <= '0';
				Lda <= '0';
				IT <= '0';

			WHEN OTHERS => NULL;
		END CASE;
	END PROCESS;
END FSM;