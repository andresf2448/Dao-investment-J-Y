# Deploy And Seed Flow

Este documento describe, paso por paso, como funciona actualmente el despliegue principal en [script/deploy/DeployInvestmentDao.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:1) y como funciona el seed local en [script/local/SeedLocal.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:1).

## Objetivo del deploy principal

El script `DeployInvestmentDao` hace tres cosas de alto nivel:

1. Prepara la configuracion de red activa.
2. Despliega todos los contratos en el orden correcto, resolviendo dependencias.
3. Ejecuta configuraciones administrativas posteriores al deploy, genera `deployments/<network>.json` y prepara la estructura del SDK.

## Punto de entrada

La funcion de entrada es [run()](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:27).

Dentro de `run()` pasa esto:

1. Se crea `HelperConfig`.
2. Se obtiene `networkConfig`.
3. Se deriva la address del deployer desde `networkConfig.deployerPrivateKey`.
4. Si la red es Anvil (`chainid == 31337`), se despliegan mocks y se reemplazan placeholders de config.
5. Se llama `deployContracts(...)`.
6. Se genera `deployments/<network>.json`.
7. Se crea la estructura base de `contracts-sdk/src`.

## Ajuste previo para Anvil

En [líneas 32-41](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:32), si la red es local:

1. Se ejecuta `DeployMocks.run()`.
2. Se obtiene:
   - `mockERC20`
   - `mockAavePool`
3. Se actualiza `networkConfig`:
   - `allowedGenesisTokens[0] = mockERC20`
   - `allowedVaultToken = mockERC20`
   - `aavePool = mockAavePool`

Intencion:
- evitar placeholders `address(0)` en local
- garantizar que el deploy principal use mocks reales desde el inicio

## Flujo completo de `deployContracts(...)`

La funcion principal del despliegue real es [deployContracts(...)](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:81).

### 1. DeployTimeLock

Se ejecuta en [líneas 104-105](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:104).

Script usado: [DeployTimeLock.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployTimeLock.s.sol:8)

Parametros que recibe:
- `config`
- `deployer`

Internamente usa:
- `deployerPrivateKey`
- `minDelay`
- `proposers`
- `executors`
- `admin`

Valor importante:
- en Anvil `minDelay = 0`
- en otras redes `minDelay = 10`

Resultado:
- despliega `TimeLock`
- el deployer queda inicialmente como proposer, executor y admin opcional
- el propio timelock tambien queda auto-administrado por OZ

### 2. DeployGovernanceToken

Se ejecuta en [líneas 107-108](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:107).

Script usado: [DeployGovernanceToken.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployGovernanceToken.s.sol:8)

Parametros:
- `config`
- `deployer`

Resultado:
- despliega `GovernanceToken`
- el admin inicial del token queda en el deployer

### 3. DeployTreasury

Se ejecuta en [líneas 110-111](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:110).

Script usado: [DeployTreasury.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployTreasury.s.sol:8)

Parametros:
- `config`
- `address(timeLock)`
- `deployer`

Resultado:
- despliega `Treasury`
- lo deja apuntando al `TimeLock`
- tambien recibe el deployer como rol operativo secundario del constructor de `Treasury`

### 4. DeployGenesisBonding

Se ejecuta en [líneas 113-120](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:113).

Script usado: [DeployGenesisBonding.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployGenesisBonding.s.sol:9)

Parametros:
- `config`
- `address(governanceToken)`
- `treasury`
- `deployer`
- `networkConfig.allowedGenesisTokens`

Internamente, `GenesisBonding` se despliega con:
- `adminTimelock = deployer`
- `sweepRole = deployer`
- `allowedGenesisTokens = allowedTokens`
- `governanceToken_ = governanceToken`
- `treasury_ = treasury`
- `rate_ = 100`

Resultado:
- despliega `GenesisBonding`
- el contrato queda listo para vender governance token a cambio de los `allowedGenesisTokens`

### 5. Transferencia y ajuste de roles del GovernanceToken

Este bloque ocurre inmediatamente despues de `DeployGenesisBonding`, en [líneas 122-126](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:122).

```solidity
vm.startBroadcast(networkConfig.deployerPrivateKey);
governanceToken.grantRole(governanceToken.MINTER_ROLE(), genesisBonding);
governanceToken.grantRole(governanceToken.DEFAULT_ADMIN_ROLE(), address(timeLock));
governanceToken.revokeRole(governanceToken.DEFAULT_ADMIN_ROLE(), deployer);
vm.stopBroadcast();
```

Que hace este bloque:

1. Le da `MINTER_ROLE` a `genesisBonding`.
   Intencion:
   `GenesisBonding.buy(...)` mintea governance token al comprador, por eso necesita permiso para mintear.

2. Le da `DEFAULT_ADMIN_ROLE` al `TimeLock`.
   Intencion:
   que la administracion futura del token quede bajo gobernanza/timelock y no en una wallet externa.

3. Le quita `DEFAULT_ADMIN_ROLE` al deployer.
   Intencion:
   eliminar privilegios administrativos directos del deployer sobre el token una vez terminado el bootstrap.

Estado final esperado de esta parte:
- `genesisBonding` puede mintear
- `timeLock` administra el token
- el deployer ya no es admin del token

### 6. DeployDaoGovernor

Se ejecuta en [líneas 128-129](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:128).

Script usado: [DeployDaoGovernor.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployDaoGovernor.s.sol:10)

Parametros:
- `config`
- `address(governanceToken)`
- `address(timeLock)`
- `deployer`

Internamente se despliega `DaoGovernor` con:
- `governanceToken`
- `timelock`
- `minProposalThreshold_ = 1000e18`
- `minVotingDelay_ = 1`
- `minVotingPeriod_ = 45818`

Resultado:
- despliega el contrato de gobernanza principal del protocolo

### 7. DeployProtocolCore

Se ejecuta en [líneas 131-132](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:131).

Script usado: [DeployProtocolCore.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployProtocolCore.s.sol:9)

Parametros:
- `config`
- `address(timeLock)`
- `deployer`
- `networkConfig.allowedGenesisTokens`
- `networkConfig.allowedVaultToken`

Internamente despliega:
- implementación `ProtocolCore`
- `ERC1967Proxy`

Y llama `initialize(...)` con:
- `adminTimelock = timeLock`
- `emergencyOperator = deployer`
- `allowedGenesisTokens`
- `allowedVaultToken`

Resultado:
- `ProtocolCore` queda upgradeable
- el `TimeLock` queda como admin/manager
- el deployer queda como emergency operator
- los `allowedGenesisTokens` quedan registrados
- el `allowedVaultToken` queda marcado como vault asset soportado

### 8. DeployRiskManager

Se ejecuta en [líneas 134-135](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:134).

Script usado: [DeployRiskManager.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployRiskManager.s.sol:9)

Parametros:
- `config`
- `address(timeLock)`
- `deployer`

Resultado:
- despliega implementación + proxy de `RiskManager`
- `TimeLock` queda como manager/admin
- deployer queda como emergency operator

### 9. DeployGuardianAdministrator

Se ejecuta en [líneas 137-138](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:137).

Script usado: [DeployGuardianAdministrator.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployGuardianAdministrator.s.sol:9)

Parametros:
- `config`
- `daoGovernor`
- `address(timeLock)`
- `deployer`

Internamente se despliega con:
- `governor_ = daoGovernor`
- `timelock_ = timeLock`
- `minStake_ = 100`

Resultado:
- despliega `GuardianAdministrator`
- queda conectado a gobernanza y timelock
- todavia no queda enlazado con `GuardianBondEscrow`; eso se configura despues por timelock

### 10. DeployGuardianBondEscrow

Se ejecuta en [líneas 140-148](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:140).

Script usado: [DeployGuardianBondEscrow.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployGuardianBondEscrow.s.sol:9)

Parametros:
- `config`
- `treasury`
- `guardianAdministrator`
- `address(timeLock)`
- `networkConfig.allowedGenesisTokens[0]`
- `deployer`

Internamente se despliega con:
- token de bond = `allowedGenesisTokens[0]`
- treasury = `treasury`
- adminTimelock = `timeLock`
- guardianAdministrator = `guardianAdministrator`

Resultado:
- despliega `GuardianBondEscrow`
- el escrow ya conoce que el `guardianAdministrator` es quien interactuara con bonds

### 11. DeployVaultRegistry

Se ejecuta en [líneas 150-151](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:150).

Script usado: [DeployVaultRegistry.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployVaultRegistry.s.sol:8)

Parametros:
- `config`
- `address(timeLock)`
- `deployer`

Resultado:
- despliega `VaultRegistry`
- el admin del registry queda bajo `TimeLock`
- todavia no queda asociada la `VaultFactory`; eso se configura despues por timelock

### 12. DeployStrategyRouter

Se ejecuta en [líneas 153-155](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:153).

Script usado: [DeployStrategyRouter.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployStrategyRouter.s.sol:10)

Parametros:
- `config`
- `address(timeLock)`
- `riskManager`
- `address(vaultRegistry)`
- `deployer`

Internamente inicializa con:
- `adminTimelock = timeLock`
- `riskManager`
- `vaultRegistry`

Resultado:
- despliega `StrategyRouter`
- queda conectado al `RiskManager` y `VaultRegistry`

### 13. DeployVaultImplementation

Se ejecuta en [líneas 157-158](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:157).

Script usado: [DeployVaultImplementation.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployVaultImplementation.s.sol:8)

Parametros:
- `config`
- `deployer`

Resultado:
- despliega la implementación base del vault
- esta implementación luego sera usada por la factory

### 14. DeployVaultFactory

Se ejecuta en [líneas 160-170](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:160).

Script usado: [DeployVaultFactory.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployVaultFactory.s.sol:8)

Parametros:
- `config`
- `address(timeLock)`
- `vaultImplementation`
- `guardianAdministrator`
- `vaultRegistry`
- `strategyRouter`
- `protocolCore`
- `deployer`

Resultado:
- despliega `VaultFactory`
- queda conectada con la implementación, guardian admin, registry, router y core

### 15. DeployAaveV3Adapter

Se ejecuta en [líneas 172-173](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:172).

Script usado: [DeployAaveV3Adapter.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployAaveV3Adapter.s.sol:8)

Parametros:
- `config`
- `strategyRouter`
- `networkConfig.aavePool`
- `deployer`

Resultado:
- despliega el adapter de Aave
- lo deja ligado al router y al pool configurado

## Configuraciones posteriores al deploy

Despues de desplegar todos los contratos, se ejecuta [\_configureProtocolDefaults(...)](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:254).

Actualmente hace dos configuraciones administrativas por timelock:

1. `GuardianAdministrator.setBondEscrow(guardianBondEscrow)`
2. `VaultRegistry.setFactory(vaultFactory)`

Estas configuraciones usan [\_scheduleAndMaybeExecute(...)](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:231).

### Como funciona `_scheduleAndMaybeExecute(...)`

Parametros:
- `deployerPrivateKey`
- `timeLock`
- `target`
- `data`
- `salt`

Flujo:

1. construye `predecessor = bytes32(0)`
2. consulta `minDelay = timeLock.getMinDelay()`
3. hace `timeLock.schedule(...)`
4. si `minDelay == 0`, hace `timeLock.execute(...)`
5. si `minDelay > 0`, deja la operacion programada y la reporta por log

Implicacion:
- en Anvil, la configuración se agenda y ejecuta en la misma corrida
- en una red con delay real, la configuracion queda programada y pendiente de ejecución posterior manual.

## Ajuste final de admin del TimeLock

En [líneas 184-187](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:184) pasa esto:

```solidity
vm.startBroadcast(networkConfig.deployerPrivateKey);
  timeLock.grantRole(timeLock.DEFAULT_ADMIN_ROLE(), daoGovernor);
  timeLock.renounceRole(timeLock.DEFAULT_ADMIN_ROLE(), deployer);
vm.stopBroadcast();
```

Que hace:

1. le da `DEFAULT_ADMIN_ROLE` al `daoGovernor`
2. el deployer renuncia a su `DEFAULT_ADMIN_ROLE`

Intencion:
- mover la administracion del timelock hacia la gobernanza
- quitar privilegios directos del deployer al terminar el bootstrap

Importante:
- el propio timelock sigue siendo self-admin internamente por diseño de OZ
- lo que se elimina es el admin externo temporal del deployer

## Archivos generados y pasos finales

Despues del deploy:

### `generateDeploymentsJson(...)`

Funciona en [líneas 279-326](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:279)

Hace esto:
- crea carpeta `deployments` si no existe
- construye `deployments/<network>.json`
- serializa addresses clave del despliegue

Campos importantes:
- `aavePool`
- `timeLock`
- `governanceToken`
- `treasury`
- `daoGovernor`
- `protocolCore`
- `riskManager`
- `guardianAdministrator`
- `guardianBondEscrow`
- `vaultRegistry`
- `strategyRouter`
- `vaultImplementation`
- `genesisBonding`
- `vaultFactory`
- `aaveV3Adapter`

### `createContractsSdkStructure()`

Funciona en [líneas 328-346](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol:328)

Hace esto:
- crea `contracts-sdk/src`
- crea subcarpetas:
  - `abi`
  - `addresses`
  - `helpers`

Intencion:
- dejar listo el terreno para generar y consumir el SDK de contratos

## Resumen corto del orden de despliegue

El orden final es:

1. `TimeLock`
2. `GovernanceToken`
3. `Treasury`
4. `GenesisBonding`
5. ajuste de roles de `GovernanceToken`
6. `DaoGovernor`
7. `ProtocolCore`
8. `RiskManager`
9. `GuardianAdministrator`
10. `GuardianBondEscrow`
11. `VaultRegistry`
12. `StrategyRouter`
13. `VaultImplementation`
14. `VaultFactory`
15. `AaveV3Adapter`
16. configuraciones post-deploy por timelock
17. migracion de admin del timelock al governor
18. escritura de `deployments/<network>.json`
19. preparacion de carpetas del SDK

---

# SeedLocal Paso A Paso

El archivo [SeedLocal.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:1) no despliega infraestructura. Su objetivo es dejar el protocolo local en un estado util para pruebas manuales, frontend o demos.

Estado final que busca:

1. un guardian activo
2. dos inversionistas
3. governance token comprado por esos actores
4. un vault creado
5. dos depositos dentro del vault

## Restriccion de red

En [línea 30](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:30):

```solidity
require(block.chainid == 31337, "SeedLocal only supports Anvil");
```

Intención:
- impedir uso accidental fuera de Anvil
- este seed asume timelock con `minDelay = 0`

## Carga de addresses desplegadas

En [líneas 32-42](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:32) lee `deployments/anvil.json` y obtiene:

- `timeLock`
- `guardianAdministrator`
- `guardianBondEscrow`
- `genesisBonding`
- `governanceToken`
- `vaultFactory`

Luego deriva `mockUsdc` consultando `GuardianBondEscrow.guardianApplicationToken()`.

Intencion:
- operar contra el deployment real mas reciente

## Creacion de participantes

En [líneas 44-50](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:44) se crean tres cuentas deterministicas:

1. `guardian`
2. `investor1`
3. `investor2`

Se usa `makeAddrAndKey(...)`, asi que las cuentas son repetibles entre corridas.

## Paso 1 del seed: dar ETH para gas

En [líneas 56-58](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:56) se llama `\_fundAccount(...)`.

Helper: [líneas 89-94](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:89)

Que hace:
- el deployer manda ETH a cada participante

Intencion:
- permitir que esas cuentas paguen gas cuando ejecuten approvals, compras, aplicaciones y depositos

## Paso 2 del seed: mintear Mock USDC

En [líneas 60-62](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:60) se llama `\_mintUsdc(...)`.

Helper: [líneas 96-100](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:96)

Distribucion:
- guardian: `GUARDIAN_BOND + GUARDIAN_GVT_BUY`
- investor1: `INVESTOR1_GVT_BUY + INVESTOR1_DEPOSIT`
- investor2: `INVESTOR2_GVT_BUY + INVESTOR2_DEPOSIT`

Intencion:
- cada cuenta recibe exactamente lo que necesita para su flujo

## Paso 3 del seed: compra de governance por el guardian

En [línea 64](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:64) se llama `\_buyAndDelegateGuardianVotes(...)`.

Helper: [líneas 102-115](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:102)

Que hace:

1. el guardian aprueba `GenesisBonding`
2. el guardian compra governance token usando `mockUsdc`
3. el guardian delega sus votos a `guardianAdministrator`
4. el script avanza un bloque con `vm.roll(block.number + 1)`

Intencion:
- darle governance token al guardian
- dejar la delegacion registrada para snapshots/checkpoints de gobernanza antes de avanzar

## Paso 4 del seed: activacion del guardian

En [líneas 65-72](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:65) se llama `\_activateGuardian(...)`.

Helper: [líneas 117-145](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:117)

### Fase A: aplicacion del guardian

En [líneas 125-128](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:125):

1. el guardian aprueba `guardianBondEscrow` para tomar el bond
2. llama `GuardianAdministrator.applyGuardian()`

Intencion:
- iniciar el flujo formal de aplicacion
- bloquear el bond requerido por el sistema

### Fase B: aprobacion por timelock

En [líneas 130-143](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:130):

1. construye `salt`
2. construye el calldata de `guardianApprove(guardian.addr)`
3. hace `TimeLock.schedule(...)`
4. hace `TimeLock.execute(...)`

Intencion:
- aprobar al guardian por la misma via administrativa que usaria el protocolo

Importante:
- este flujo esta pensado para local
- depende de que `TimeLock.getMinDelay()` sea `0`

## Paso 5 del seed: crear el vault

En [línea 74](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:74) se llama `\_createVault(...)`.

Helper: [líneas 147-151](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:147)

Que hace:
- el guardian crea un vault con:
  - asset = `mockUsdc`
  - name = `Seed Vault`
  - symbol = `sVAULT`

Intencion:
- dejar al menos un vault funcional en el protocolo

## Paso 6 del seed: compra de governance por inversionistas

En [líneas 75-76](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:75) se llama `\_buyGovernanceForInvestor(...)` para ambos inversionistas.

Helper: [líneas 153-163](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:153)

Que hace:

1. cada inversionista aprueba `GenesisBonding`
2. cada inversionista compra governance token

Intencion:
- poblar el sistema con mas participantes de gobernanza

## Paso 7 del seed: depositos en el vault

En [líneas 77-78](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:77) se llama `\_depositToVault(...)` para ambos inversionistas.

Helper: [líneas 165-169](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol:165)

Que hace:

1. cada inversionista aprueba el vault
2. llama `IERC4626(vault).deposit(amount, investor.addr)`

Intencion:
- dejar TVL real en el vault
- emitir shares a los inversionistas
- tener un estado util para frontend y pruebas manuales

## Resumen corto del seed

El orden del seed es:

1. leer addresses del deployment
2. crear guardian e inversionistas
3. darles ETH para gas
4. mintear Mock USDC
5. hacer que el guardian compre governance y delegue votos
6. aplicar y aprobar al guardian
7. crear un vault
8. hacer que los inversionistas compren governance token
9. depositar capital en el vault
10. imprimir addresses utiles

## Estado final esperado despues del seed

Si todo sale bien, al terminar deberias tener:

1. `guardian` activo
2. `investor1` e `investor2` con governance token
3. un `vault` creado
4. dos depositos hechos en ese vault
5. un entorno local listo para probar flujos reales del protocolo
