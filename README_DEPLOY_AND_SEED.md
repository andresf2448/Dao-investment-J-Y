# Deploy And Seed Flow

Este documento resume el flujo actual de despliegue y seed local del protocolo.

Archivos principales:
- [script/deploy/DeployInvestmentDao.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/deploy/DeployInvestmentDao.s.sol)
- [script/local/SeedLocal.s.sol](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/script/local/SeedLocal.s.sol)

## Comandos principales

Para levantar un entorno local completo en Anvil:

```bash
make s_deployLocal
make s_seedLocal
```

El primer comando despliega toda la infraestructura del protocolo y genera `deployments/anvil.json`.  
El segundo comando completa el estado local con usuarios, guardianes, vaults, actividad económica, propuestas demo y `deployments/anvil-seed.json`.

## Deploy principal

El punto de entrada es `DeployInvestmentDao.run()`.

Responsabilidades de alto nivel:
- cargar la configuración de red activa desde `HelperConfig`
- desplegar mocks si la red es `31337`
- desplegar contratos en orden resolviendo dependencias
- aplicar configuraciones post-deploy
- generar `deployments/<network>.json`
- regenerar `contracts-sdk`

## Configuración de red

`HelperConfig` soporta hoy:
- `anvil`
- `sepolia`

En Anvil:
- `allowedGenesisTokens[0]` inicia como placeholder
- `allowedVaultToken` inicia como placeholder
- `aavePool` inicia como placeholder
- esos valores se reemplazan durante el deploy con mocks reales

En Sepolia:
- se usa el token configurado en `HelperConfig`
- se usa el pool real de Aave configurado allí

## Flujo de deploy en Anvil

Cuando `chainid == 31337`, `DeployInvestmentDao` ejecuta `DeployMocks.run()` antes del resto del despliegue.

Eso produce:
- `MockERC20`
- `MockAavePool`

Y luego actualiza `networkConfig` con:
- `allowedGenesisTokens[0] = mockERC20`
- `allowedVaultToken = mockERC20`
- `aavePool = mockAavePool`

Esto garantiza que el resto del deploy use dependencias funcionales en local desde el inicio.

## Orden de despliegue

El orden actual en `deployContracts(...)` es este:

1. `TimeLock`
2. `GovernanceToken`
3. `Treasury`
4. `GenesisBonding`
5. `DaoGovernor`
6. `ProtocolCore`
7. `RiskManager`
8. `GuardianAdministrator`
9. bootstrap especial de `GovernanceToken` y `GuardianAdministrator`
10. `GuardianBondEscrow`
11. `VaultRegistry`
12. `StrategyRouter`
13. `VaultImplementation`
14. `VaultFactory`
15. `AaveV3Adapter`
16. configuración post-deploy vía `TimeLock`
17. transferencia final del admin del `TimeLock` al `DaoGovernor`

## Qué hace cada despliegue

### 1. TimeLock

Se despliega primero porque es la base administrativa del protocolo.

Estado relevante:
- en Anvil el `minDelay` es `0`
- en redes no locales puede ser mayor
- el deployer queda inicialmente con permisos suficientes para terminar el bootstrap

### 2. GovernanceToken

Se despliega con el deployer como admin inicial temporal.

Luego, durante el bootstrap:
- se da `MINTER_ROLE` a `GenesisBonding`
- se da `MINTER_ROLE` temporal al deployer
- el deployer mintea al `GuardianAdministrator` exactamente `proposalThreshold()`
- el deployer revoca su propio `MINTER_ROLE`
- se entrega `DEFAULT_ADMIN_ROLE` al `TimeLock`
- se revoca `DEFAULT_ADMIN_ROLE` al deployer

La intención es:
- permitir ventas de `GenesisBonding`
- asegurar que `GuardianAdministrator` tenga poder de voto suficiente para proponer
- dejar la administración final del token en manos del `TimeLock`

### 3. Treasury

Se despliega apuntando al `TimeLock`.

Rol esperado:
- custodiar activos del protocolo
- quedar administrado por el flujo de gobernanza/timelock

### 4. GenesisBonding

Se despliega con:
- `governanceToken`
- `treasury`
- lista inicial de `allowedGenesisTokens`
- `rate = 100`

Después del bootstrap queda habilitado para mintear governance token porque recibe `MINTER_ROLE` sobre `GovernanceToken`.

### 5. DaoGovernor

Se despliega conectado a:
- `GovernanceToken`
- `TimeLock`

Parámetros relevantes:
- `proposalThreshold = 1000e18`
- `votingDelay = 1`
- `votingPeriod = 20` en Anvil
- `votingPeriod = 45818` fuera de Anvil

Además, `DaoGovernor` hereda `GovernorStorage`, así que conserva propuestas on-chain y expone utilidades como `proposalCount()` y `proposalDetailsAt(...)`.

### 6. ProtocolCore

Se despliega como implementación + `ERC1967Proxy`.

Se inicializa con:
- `adminTimelock = timeLock`
- `emergencyOperator = deployer`
- `allowedGenesisTokens`
- `allowedVaultToken`

Resultado:
- el token genesis configurado queda permitido desde el arranque
- el asset de vault inicial queda soportado

### 7. RiskManager

Se despliega también como implementación + proxy.

Queda enlazado al `TimeLock` para administración y al deployer como operador de emergencia inicial.

### 8. GuardianAdministrator

Se despliega con:
- `DaoGovernor`
- `TimeLock`
- token de bond inicial

Bootstrap adicional importante:
- el deployer mintea a `GuardianAdministrator` el `proposalThreshold()` exacto
- luego `GuardianAdministrator.selfDelegateGovernanceVotes(...)` se ejecuta

Eso permite que el propio `GuardianAdministrator` pueda generar propuestas de onboarding de guardianes sin depender de una wallet externa.

### 9. GuardianBondEscrow

Se despliega con:
- `treasury`
- `guardianAdministrator`
- `timeLock`
- token de aplicación de guardianes

Después del deploy, `GuardianAdministrator` se enlaza con este contrato vía una operación del `TimeLock`.

### 10. VaultRegistry

Se despliega como registro central de vaults.

Después del deploy, se configura su factory válida vía `TimeLock`.

### 11. StrategyRouter

Se despliega como implementación + proxy.

Se inicializa con:
- `TimeLock`
- `RiskManager`
- `VaultRegistry`

### 12. VaultImplementation

Se despliega la implementación base de los vaults ERC4626 del protocolo.

### 13. VaultFactory

Se despliega conectada a:
- `TimeLock`
- `VaultImplementation`
- `GuardianAdministrator`
- `VaultRegistry`
- `StrategyRouter`
- `ProtocolCore`

Esta factory es la encargada de crear nuevos vaults guardian-managed.

### 14. AaveV3Adapter

Se despliega conectado a:
- `StrategyRouter`
- `aavePool` de la red activa

En Anvil usa `MockAavePool`.

## Configuración post-deploy

`DeployInvestmentDao` configura dos defaults vía `TimeLock`:

1. `GuardianAdministrator.setBondEscrow(guardianBondEscrow)`
2. `VaultRegistry.setFactory(vaultFactory)`

Esto se hace con `_scheduleAndMaybeExecute(...)`.

Comportamiento:
- si `minDelay == 0`, se `schedule` y `execute` en el mismo deploy
- si `minDelay > 0`, la operación queda programada y pendiente de ejecución posterior

## Transferencia final del control del TimeLock

Al final del deploy:
- se da `DEFAULT_ADMIN_ROLE` del `TimeLock` al `DaoGovernor`
- el deployer renuncia a ese admin

Resultado esperado:
- la autoridad de gobierno termina en el `DaoGovernor`
- el deployer deja de tener control administrativo directo del `TimeLock`

## Archivos generados por el deploy

El deploy principal genera:
- `deployments/<network>.json`
- `contracts-sdk/src/abi/*`
- `contracts-sdk/src/addresses/*`
- `contracts-sdk/src/helpers/*`

En Anvil, el archivo normal es:
- [deployments/anvil.json](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/deployments/anvil.json)

Ese archivo contiene las direcciones base del protocolo y es la fuente que consume `SeedLocal`.

## Seed local

El punto de entrada del seed es `SeedLocal.run()`.

Restricción importante:
- solo corre en `chainid == 31337`

Objetivo:
- dejar un entorno local rico y navegable para frontend y testing manual

## Qué hace el seed local

`SeedLocal` hoy hace todo esto:

1. lee `deployments/anvil.json`
2. deriva y construye participantes determinísticos
3. fondea todas las cuentas con ETH
4. otorga a `ADMIN_WALLET_ANVIL_PRIVATE_KEY` acceso amplio por roles
5. otorga al `DaoGovernor` los roles necesarios del `TimeLock`
6. despliega un segundo `MockERC20`
7. registra ese segundo token como:
   - genesis token permitido
   - asset soportado para vaults
   - token de compra válido en `GenesisBonding`
8. mintea balances iniciales a guardianes e inversores
9. activa tres guardianes reales
10. crea tres vaults
11. hace compras reales de governance token
12. hace depósitos reales en vaults
13. mintea governance token a actores de gobernanza demo
14. delega votos a cada actor
15. crea propuestas demo en múltiples estados
16. valida on-chain el resultado
17. imprime logs finales
18. persiste `deployments/anvil-seed.json`

## Participantes seeded

El seed crea estos grupos de actores:

### Guardianes

- `guardian1`
- `guardian2`
- `adminGuardian = vm.addr(ADMIN_WALLET_ANVIL_PRIVATE_KEY)`

Estado final:
- los tres quedan como guardianes activos
- `adminGuardian` no recibe vaults

### Inversores

- `investor1`
- `investor2`

Estado final:
- hacen compras en `GenesisBonding`
- depositan en vaults

### Actores de gobernanza demo

- `proposerPending`
- `proposerActive`
- `proposerCanceled`
- `proposerDefeated`
- `proposerSucceeded`
- `proposerQueued`
- `proposerExecuted`
- `voter1`
- `voter2`
- `voter3`

Todos reciben governance token y hacen `delegate` a sí mismos.

## Assets seeded

El seed trabaja con dos tokens locales:

- `primaryGenesisToken`
  Es el token de aplicación de guardianes y el token inicial que ya venía del deploy.

- `secondaryGenesisToken`
  Es un nuevo `MockERC20` desplegado dentro del seed.

Estado final esperado:
- ambos están en `ProtocolCore.getSupportedGenesisTokens()`
- ambos quedan soportados como vault assets
- ambos quedan habilitados como purchase tokens de `GenesisBonding`

## Guardianes y vaults seeded

El seed deja:

- `guardian1` activo con 2 vaults
- `guardian2` activo con 1 vault
- `adminGuardian` activo sin vault

Distribución de vaults:
- `guardian1` vault con asset primario
- `guardian2` vault con asset primario
- `guardian1` vault adicional con asset secundario

Además, la wallet admin recibe roles administrativos sobre los vaults creados.

## Actividad económica seeded

El seed deja actividad visible para frontend:

- `investor1` compra governance token con el token primario
- `investor2` compra governance token con el token secundario
- `investor1` deposita en el primer vault
- `investor2` deposita en el segundo vault
- `investor2` deposita en el vault del asset secundario

Esto asegura que:
- `GenesisBonding` quede probado con ambos assets
- existan balances y movimiento real en los vaults

## Roles extra seeded

Además del acceso amplio para `ADMIN_WALLET_ANVIL_PRIVATE_KEY`, el seed también da al `DaoGovernor` estos roles en `TimeLock`:

- `PROPOSER_ROLE`
- `EXECUTOR_ROLE`
- `CANCELLER_ROLE`

Esto es importante para poder sembrar estados reales como `Queued` y `Executed` usando el governor.

## Propuestas demo seeded

El seed crea propuestas demo etiquetadas por estado:

- `Pending`
- `Active`
- `Canceled`
- `Defeated`
- `Succeeded`
- `Queued`
- `Executed`

No crea `Expired`, porque con la herencia actual del governor ese estado no se está usando como estado práctico del flujo local.

Las propuestas usan una acción inocua e idempotente sobre `ProtocolCore`:
- `setSupportedVaultAsset(secondaryToken, true)`

La razón es simple:
- no rompe el sistema
- puede repetirse
- permite recorrer el ciclo de gobernanza real

## Validaciones incluidas en el seed

Antes de terminar, `SeedLocal` valida on-chain con `require(...)`:

- que existan 2 genesis tokens soportados
- que existan 2 vault assets soportados
- que los 3 guardianes estén activos
- que `guardian1` tenga 2 vaults
- que `guardian2` tenga 1 vault
- que `adminGuardian` tenga 0 vaults
- que los 3 vaults estén activos
- que hubo compra de governance token usando el token secundario
- que cada propuesta demo esté en el estado esperado
- que el `proposalCount()` del governor haya aumentado exactamente en 7 propuestas demo

## Logs y JSON del seed

Al final del seed se imprimen logs con:
- tokens
- guardianes
- vaults
- proposal ids de aplicación de guardianes
- proposal ids demo por estado
- proposal count antes y después
- state numérico final de cada proposal demo

Además, solo en Anvil, se escribe:
- [deployments/anvil-seed.json](/home/andres/Documentos/Solidity%20Projects/Dao-Investment-J-Y/deployments/anvil-seed.json)

Ese JSON contiene:
- `primaryGenesisToken`
- `secondaryGenesisToken`
- `supportedGenesisTokens`
- `supportedVaultAssets`
- `guardians`
- `vaultsByGuardian`
- `proposalIdsByState`
- `guardianApplicationProposalIds`

## Qué consume el frontend

En local, el frontend puede apoyarse en dos archivos:

- `deployments/anvil.json`
  Direcciones base del protocolo.

- `deployments/anvil-seed.json`
  Estado seeded adicional útil para mostrar data rica desde el primer render.

## Resumen práctico

Si quieres un entorno local completo:

1. corre `make s_deployLocal`
2. corre `make s_seedLocal`
3. usa `deployments/anvil.json` para direcciones base
4. usa `deployments/anvil-seed.json` para data seeded adicional

Con eso deberías tener:
- protocolo desplegado
- guardianes activos
- vaults creados y activos
- compras y depósitos reales
- propuestas demo en varios estados
- SDK regenerado
