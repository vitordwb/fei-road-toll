--****************************
-- CENTRO UNIVERSITARIO FEI
-- Sistemas Digitais II  -  Projeto 2  - 1° Semestre de 2021
-- Componente VHDL: Unidade de Controle do Sisttema de Pedágio => UC.vhd
-- Rev. 0
-- Especificações: entradas: CK, RT, IC, DC, RP, PP, MO, ZR, PO, NG, ES, FT
-- 			 saidas: Sel_mxa[2..0], Sel_mxb[2..0], Sel_ula[1..0],Lda, Ldb, Ldc,IT
--				 saidas externas: MFC, MEV, LDM
-- Esse código é um padrão de referência (template) para o código da UC que deve
--****************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity UC is
port(	CK	: in std_logic;				-- clock de 50MHz
		RT	: in std_logic;				-- reinicio total -> ativo em zero
-- Entradas Externas:
		IC	: in std_logic; 			-- incrementa credito -> ativo em um
		DC	: in std_logic; 			-- decrementa credito -> ativo em um
		RP	: in std_logic; 			-- reinicio parcial -> ativo em um
		PP	: in std_logic; 			-- passagem pelo portico -> ativo em um
		MO	: in std_logic; 			-- modo de operação -> 1= Normal, 0= Ajusta Valor
-- Sinais de Estado da ULA:
		ZR	: in std_logic;			-- resultado zero na operação da ULA
		PO	: in std_logic;			-- resultado positivo na operação da ULA
		NG	: in std_logic;			-- resultado negativo na operação da ULA
		ES	: in std_logic;			-- resultado da operação da ULA maior que 255
-- Sinais de Estado do TIMER:
		FT	: in std_logic;			-- fim da temporização de 1 segundo
-- Sinais de Saida para MUX:
		Sel_mxa : out std_logic_vector(2 downto 0); 	-- seleciona entrada de MUX_A
		Sel_mxb : out std_logic_vector(2 downto 0);	-- seleciona entrada de MUX_B
-- Sinais de Saida para ULA:
		Sel_ula : out std_logic_vector(1 downto 0);	-- seleciona operação da ULA
-- Sinais de Saida para Registradores:
		Lda	: out std_logic;		-- carrega RA
		Ldb	: out std_logic;		-- carrega RB
		Ldc	: out std_logic;		-- carrega RC
-- Sinais de Saida para TIMER:
		IT		: out std_logic;		-- inicia temporização
-- Sinais de Saida Externos:
		MEV	:  out std_logic;		-- sinaliza multa por excesso de velocidade 
		MFC	:  out std_logic;		-- sinaliza multa por falta de crédito
		SDM	:  out std_logic 		-- sinaliza limite de distância total percorrida 
	);
end UC;
----------------------------------------------------------------------------------
architecture FSM of UC is
type ESTADOS_ME is (
	 ZER_RG	-- zera registrador
	,CAR_CR	-- carrega credito
	,AJU_CR	-- ajusta credito
	,INC_CR	-- incrementa credito
	,VER_CRM -- verifica crm
	,MAX_CR	-- max valor de cr
	,DEC_CR	-- decrementa cr
	,MIN_CR	-- minimo valor de cr
	,INC_DP	-- incrementa dp
	,INC_DP2 -- incrementa dp segundo estado
	,VER_DT	-- verifica dt
	,VER_CR	-- verifica cr
	,SIN_LIM -- sinaliza limite
	,MUL_CR	-- multa credito
	,VF15  	-- espera pp ou dispara timer
	,VF16    -- reinicia dp e reinicia mev
	,REI_DP 	-- reinicia dp
	,REI_MEV -- reinicia mev
	,VER_VEL	-- verifica velocidade
	,MUL_VEL -- multa velocidade
						 
						 );
signal E: ESTADOS_ME;
begin
process(CK, RT)
begin
if RT='0' then E <= ZER_RG;	  						-- zera registros
			   MFC <= '0'; MEV <= '0'; SDM<='0';	-- zera multas	e sinalização 		
elsif (CK'event and CK='1') then
 case E is
	when ZER_RG =>
					E <= CAR_CR;			-- carrega CR com credito inicial
	when CAR_CR =>
					E <= AJU_CR;	 		--- espera IC e DC com MO=0 para ajustar CR
	when AJU_CR =>
				if MO = '1' and PP='1' then 
					E <= INC_DP;			-- incrementa distancia parcial
				elsif MO='0' and IC='1' and DC='1' then
					E <= INC_CR;
				elsif MO='0' and IC='0' and DC='1' then
					E <= DEC_CR;
				elsif PO='0' then
					E <= VER_CRM;
				elsif MO='0' and IC='0' and DC='0' then
					E <= AJU_CR;
				end if;
	when INC_CR =>
				E <= VER_CRM;
	when VER_CRM =>
				if PO='1' then E <= MAX_CR;
				end if;
	when MAX_CR => E <= AJU_CR;
	when DEC_CR =>
				if NG='0' then E <= AJU_CR;
				elsif NG='1' then E <= MIN_CR;
				end if;
	when MIN_CR =>
				E <= AJU_CR;
	when INC_DP =>
				E <= INC_DP2;
	when INC_DP2 =>
				E <= VER_DT;
	when VER_DT =>
				if PO='1' then E <= SIN_LIM;
				elsif PO='0' then E <= VER_CR;
				end if;
	when SIN_LIM =>
				E <= VER_CR;
	when VER_CR =>
				if NG='1' then E <= MUL_CR;
				elsif NG='0' then E <= VF15;
				end if;
	when VF15 =>
				if PP='0' and RP='0' then E <= VF15;
				elsif RP='1' and PP='0' then E <= VF16;
				elsif PP='1' then E <= VER_VEL;
				end if;
	when VF16 =>
				E <= VF15;
	when VER_VEL =>
				if FT='0' then E <= MUL_VEL;
				elsif FT='1' then E <= INC_DP;
				end if;
				
	when others => Null;
 end case;
end if;
end process;

-- Atualização das Saídas para Fluxo de Dados (Multiplexadores, Registradores, ULA)
process(E)
begin
 case E is
	when ZER_RG => 				 					-- zera registros
				Sel_mxa <= "XXX"; Sel_mxb <= "011"; Sel_ula <= "00";  
				Ldc <= '1'; Ldb <= '1'; Lda <='1';  IT <= '1';
	when CAR_CR =>			 						-- carrega CR com Credito Inicial
				Sel_mxa <= "XXX"; Sel_mxb <= "101"; Sel_ula  <= "00";
				Ldc <= '0'; Ldb <= '0'; Lda <='1'; IT <= '1';
	when AJU_CR => 				 					-- espera IC e DC para ajustar CR
				Sel_mxa <= "XXX"; Sel_mxb <= "XXX"; Sel_ula  <= "XX";  
				Ldc <= '0'; Ldb <= '0'; Lda <='0';  IT <= '1';
	when INC_CR => 				 					-- incrementa CR
				Sel_mxa <= "001"; Sel_mxb <= "000"; Sel_ula  <= "10";  
				Ldc <= '0'; Ldb <= '0'; Lda <='1';  IT <= '1';
	when VER_CRM => 				 					-- verifica CRM
				Sel_mxa <= "101"; Sel_mxb <= "000"; Sel_ula  <= "11";  
				Ldc <= '0'; Ldb <= '0'; Lda <='0';  IT <= '1';
	when MAX_CR => 				 					-- maximo valor de CR
				Sel_mxa <= "XXX"; Sel_mxb <= "101"; Sel_ula  <= "00";  
				Ldc <= '0'; Ldb <= '0'; Lda <='1';  IT <= '1';
	when DEC_CR => 				 					-- decrementa CR
				Sel_mxa <= "001"; Sel_mxb <= "000"; Sel_ula  <= "11";  
				Ldc <= '0'; Ldb <= '0'; Lda <='1';  IT <= '1';
	when MIN_CR => 				 					-- minimo valor CR
				Sel_mxa <= "XXX"; Sel_mxb <= "111"; Sel_ula  <= "00";  
				Ldc <= '0'; Ldb <= '0'; Lda <='1';  IT <= '1';
	when INC_DP => 				 					-- incrementa DP
				Sel_mxa <= "000"; Sel_mxb <= "001"; Sel_ula  <= "10";  
				Ldc <= '0'; Ldb <= '1'; Lda <='0';  IT <= '1';	  
	when INC_DP2 => 				 					-- incrementa DP
				Sel_mxa <= "000"; Sel_mxb <= "001"; Sel_ula  <= "10";  
				Ldc <= '0'; Ldb <= '1'; Lda <='0';  IT <= '1';  
	when VER_DT => 				 					-- verifica DT
				Sel_mxa <= "111"; Sel_mxb <= "010"; Sel_ula  <= "11";  
				Ldc <= '0'; Ldb <= '0'; Lda <='0';  IT <= '1';
	when SIN_LIM => 				 					-- sinaliza limite
				Sel_mxa <= "XXX"; Sel_mxb <= "XXX"; Sel_ula  <= "XX";  
				Ldc <= '0'; Ldb <= '0'; Lda <='0';  IT <= '1';
	when VER_CR => 				 					-- verifica CR
				Sel_mxa <= "101"; Sel_mxb <= "000"; Sel_ula  <= "11";  
				Ldc <= '0'; Ldb <= '0'; Lda <='0';  IT <= '1';
	when MUL_CR => 				 					-- multa CR
				Sel_mxa <= "XXX"; Sel_mxb <= "111"; Sel_ula  <= "00";  
				Ldc <= '0'; Ldb <= '0'; Lda <='0';  IT <= '1';
	when VF15 => 				 					-- espera PP ou RP e dispara timer
				Sel_mxa <= "XXX"; Sel_mxb <= "XXX"; Sel_ula  <= "XX";  
				Ldc <= '0'; Ldb <= '0'; Lda <='0';  IT <= '0';
	when VF16 => 				 					-- reinicia DP e MEV
				Sel_mxa <= "XXX"; Sel_mxb <= "111"; Sel_ula  <= "00";  
				Ldc <= '0'; Ldb <= '1'; Lda <='0';  IT <= '0';
	when VER_VEL => 				 					-- verifica velocidade
				Sel_mxa <= "XXX"; Sel_mxb <= "XXX"; Sel_ula  <= "XX";  
				Ldc <= '0'; Ldb <= '0'; Lda <='0';  IT <= '0';
	when MUL_VEL => 				 					-- incrementa DP
				Sel_mxa <= "XXX"; Sel_mxb <= "011"; Sel_ula  <= "00";  
				Ldc <= '0'; Ldb <= '0'; Lda <='0';  IT <= '0';					
	  
	when others => Null;
 end case;
end process;
end FSM;
