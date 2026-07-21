---
title: "Práctica guiada: servidor NAS/RAID 5 con Windows Server 2025"
format: html
---

En un equipo físico, el sistema operativo podría instalarse sobre un RAID creado por una controladora hardware. Sin embargo, VirtualBox no presenta directamente una controladora RAID física al sistema invitado. Para esta simulación utilizaremos discos virtuales independientes y Espacios de almacenamiento de Windows Server.

# **Objetivos de la práctica**

Al finalizar la práctica, serás capaz de:

- Instalar Windows Server 2025 sobre un disco NVMe virtual.

- Configurar una dirección IPv4 estática.

- Crear usuarios y grupos locales.

- Crear un grupo de almacenamiento con tres discos.

- Crear un disco virtual con paridad.

- Crear y formatear un volumen NTFS.

- Publicar recursos compartidos mediante SMB.

- Diferenciar permisos de **Compartir** y permisos de **Seguridad/NTFS**.

- Configurar correctamente la herencia.

- Comprobar el acceso con distintos usuarios.

- Comprender por qué Windows no permite utilizar varios usuarios simultáneamente contra el mismo servidor SMB.

# Parte 1. Configuración de la máquina virtual.

Cada alumno creará un servidor windows a través de VirtualBox en adaptador puente.

La variable xx representa el número asignado al alumno.

Password para la práctica: Pass123!

| Elemento | Valor de ejemplo |
|:-----------------------------|:-----------------------------------------|
| **Nombre de la máquina virtual** | WS25 UEFI |
| **Nombre del servidor** | SRV-NASxx |
| **Sistema operativo** | Windows Server 2025 con Experiencia de escritorio |
| **Virtualizador** | VirtualBox 7.2.10 |
| **Red** | Adaptador puente |
| **Red IPv4** | 10.0.20.{asignada_por_dhcp}/24 |
| **Puerta de enlace** | 10.0.20.1 |
| **DNS preferido** | 8.8.8.8 |
| **DNS alternativo** | 1.1.1.1 |
| **Memoria RAM** | 4/8 GB |
| **Procesadores** | 2/4 |
| **Chipset** | ICH9 |
| **Caracteristicas** | UEFI |
| **Red** | Adaptador puente |
| **Disco del sistema** | 60 GB NVMe |
| **Disco adicional 1** | 20 GB NVMe |
| **Disco adicional 2** | 20 GB NVMe |
| **Disco adicional 3** | 20 GB NVMe |

Empezamos la creación de VM como siempre, pero hay que hacer algunos cambios antes de instalar:

Cambiar chipset:\
![](images\paste-sbQ7cxDkc-3P7qUIFah7b.png)

## Habilitar UEFI

![](images\paste-V9GU5r3aX3lmyyt8VQ4RH.png)

## **Organización de las controladoras**

La configuración quedará así:

Controladora NVMe

├── **Disco del sistema: 60 GB**

├── Disco de datos 1: 20 GB

├── Disco de datos 2: 20 GB

└── Disco de datos 3: 20 GB

Unidad óptica (CD/DVD)

└── ISO de Windows Server 2025

Los cuatro discos deben estar conectados a la controladora **NVMe**.

::: nota-importante
No conectaremos los tres discos de datos a SATA porque, en las pruebas realizadas en este entorno, VirtualBox proporcionaba identificadores repetidos y Storage Spaces no distinguía correctamente los discos.
:::

Para crear los discos en NVMe, abrimos Almacenamiento y por defecto habrá creado una unidad de disco duro de controlador SATA:\
![](images\paste-Vq0oViFs0Ectnv7bgq3TB.png)

La eliminamos clicando sobre *remove attachment*, pero conservamos la unidad óptica.

Damos a añadir controladores:\
![](images\paste-ymB6l5PUYhsg7eRaBN0Nv.png)

y seleccionamos NMVe\
![](images\paste-58jnUvfc2g5hV7b9cjjlU.png)

Entonces enlazamos la unidad de disco duro en el controlador NVMe, dándole a ***add attachment***.\
![](images\paste-gHn8VbeIB3s0gXzV27nii.png)

Ahí damos a crear para crear un disco duro que sustituya al que hemos quitado. Le daremos los 60 GB para el disco duro del SO.

![](images\paste-TH1tWd0a2ZRcWc1Us_LDk.png)

Creamos tres discos más de 20 GB y los añadimos al controlador NVMe

![](images\paste-LVwN-m87-Ped-XMfnYHHp.png)

Después de crear todos los discos nos quedará algo parecido a esto:

![](images\paste-NY1o3T_3m3673bLMDkRMr.png)

## **Configuración especial de NVMe en VirtualBox (patch)**

Oracle documenta este patch como solución provisional para huéspedes Windows que no detectan correctamente los discos conectados a la controladora NVMe. Habrá que realizar estos pasos hasta que Virtual Box solucione el problema en una versión posterior.

Antes de iniciar la máquina virutal, (con la máquina virtual completamente apagada —no guardada ni pausada—) abre CMD en el equipo anfitrión como administrador:

```         
cd "C:\Program Files\Oracle\VirtualBox"
```

Ejecuta los siguientes comandos sustituyendo el nombre de tu máquina virtual:

```         
VBoxManage setextradata "WS25 UEFI" "VBoxInternal/Devices/nvme/0/Config/MsiXSupported" 0
```

```         
VBoxManage setextradata "WS25 UEFI" "VBoxInternal/Devices/nvme/0/Config/CtrlMemBufSize" 0
```

Para comprobar que se han aplicado:

```         
VBoxManage getextradata "WS25 UEFI" enumerate
```

Deben aparecer las dos propiedades configuradas con valor 0.

\
![](images\paste-zvheMw8GQmFXm06uK9WpF.png)

## **Propuesta de direccionamiento**

Para evitar conflictos con la puerta de enlace y con otros equipos, puede utilizarse esta fórmula:

Dirección IP = 10.0.20.{asignada_por_dhcp}

Nombre: SRV-NAS01

Máscara: 255.255.255.0

Puerta de enlace: 10.0.20.1

Los discos VDI pueden ser de **reservado dinámicamente**. Windows seguirá viendo su capacidad virtual completa, aunque el archivo VDI crezca según se utilice.

## Como nos queda al final:

## ![](images\paste-PT91951uSYu2OwLfYKCEC.png)

# Parte 2: **Instalación de Windows Server 2025**

Inicia la máquina virtual desde la ISO.

Selecciona: Windows Server 2025 Standard Evaluation (Experiencia de escritorio)

![](images\paste-V9XLT9_CdZtXyXHnySmeG.png)

Cuando el instalador solicite el destino, deben aparecer cuatro discos:

- Uno de aproximadamente 60 GB.

- Tres de aproximadamente 20 GB.

Selecciona únicamente el disco de 60 GB para instalar Windows Server.\
![](images\paste-tp33XEItF-tz2dyZoyHPg.png)

No crees particiones ni volúmenes en los tres discos de 20 GB.

El instalador creará automáticamente las particiones necesarias en el disco del sistema.

**Resultado esperado**

Después de instalar Windows:

- El disco de 60 GB contendrá Windows Server.

- Los tres discos de 20 GB permanecerán vacíos.

- Los discos de datos no deberán inicializarse desde Administración de discos.

Microsoft indica que los discos destinados a Storage Spaces deben estar vacíos, sin formato y sin volúmenes. También indica que el sistema operativo no puede alojarse dentro del espacio de almacenamiento; por eso el disco del sistema queda separado del grupo.

Una vez instalado el sistema, cada vez que queramos abrirlo nos pedirá introducir Ctrl+Alt+Del, pero al ser una máquina virtual esta combinación de comandos se aplicará a la máquina host, no a la VM, así que podemos utilizar la interfaz de Virtual Box para introducirlos:\
![](images\paste-C0Zy3xHGGdc_a-nZ79VlF.png)

Finalmente se cargará el panle de Administrador del servidor:\
![](images\paste-KifpcX22ZbA5hNWfmo8v6.png)

## Instalar complementos del invitado

Seguir las instrucciones de instalación en otras prácticas de virtualización.

# **Configuración inicial del servidor**

## **Cambiar el nombre del equipo**

Desde PowerShell como administrador:

```         
Rename-Computer -NewName "SRV-NASxx" -Restart
```

Sustituye xx por el número correspondiente que se te ha asignado en clase (para evitar colisión con otros usuarios).

Después del reinicio comprobamos usando el comando `hostname`

![](images\paste-w9-Sq98p5LHAH7wsW_xZL.png)

## **Configurar la red**

en la shell usa ipconfig para ver qué dirección IP te ha asignado el DHCP, esa será la misma que configuraremos fija.\
![](images\paste-YDVUjX7coA1AsYLflTii2.png)

Panel de control

→ Redes e Internet

→ Centro de redes y recursos compartidos

→ Cambiar configuración del adaptador

![](images\paste-RiYSQMtgLxLrEfazvQzmc.png)

Abre las propiedades de Ethernet y configura IPv4.\
![](images\paste-jzMXRcuPh2s3eIk3PaIN1.png)

Comprueba la configuración: `Get-NetIPConfiguration` y haz un ping a 1.1.1.1 para comprobar que tenemos salida a internet.

![](images\paste-LZdKBranAf2bSNEsrrr8D.png)\

`Get-DnsClientServerAddress -AddressFamily IPv4`

![](images\paste-BjjEdss9K99h2mNWEa1Nm.png)

Comprueba la conectividad con el host: `Test-Connection 10.0.20.7 -Count 2`\
![](images\paste-rWHOO-qJx80QbOdv9EI8N.png)

Los Resultados

- **`Source` (Fuente)**: `SRV-NAS01`. Este es el nombre de la máquina virtual desde la que estás ejecutando el comando. Es la que envía la prueba.

- **`Destination` (Destino)**: `10.0.20.7`. Es la IP a la que estás haciendo el ping (tu máquina host).

- **`IPV4Address` / `IPV6Address`**: Estas columnas están vacías en tu imagen. Esto es normal cuando haces ping directamente a una dirección IP (como `10.0.20.7`), ya que el comando no necesita resolver un nombre de host (como `google.com`) para encontrar la IP.

- **`Bytes`**: `32`. Este es el tamaño del paquete de datos de prueba que se envió. 32 bytes es el estándar para estas pruebas.

- **`Time(ms)` (Tiempo en milisegundos)**: `0`. Esta es la métrica más importante aquí. Muestra cuánto tiempo (en milisegundos) tardó el paquete en ir desde la VM hasta el host y volver.

  - **¿Por qué `0` ms?** Esto indica una conexión extremadamente rápida y directa. Dado que estás haciendo ping desde una máquina virtual (VM) a su propia máquina anfitriona (host), el tráfico no sale a la red física real; todo sucede dentro de la memoria y la red virtual del software de virtualización (VirtualBox). Es esencialmente instantáneo, por lo que PowerShell lo redondea a 0 ms.

Comprobación DNS: `Resolve-DnsName www.microsoft.com`\
![](images\paste-bO-l-pQa5CI7FoLYWwH-1.png)

## **Establecer el perfil de red como privado**

Consulta el nombre del adaptador: `Get-NetConnectionProfile`

Si se llama Ethernet: `Set-NetConnectionProfile -InterfaceAlias "Ethernet" -NetworkCategory Private`

![](images\paste-USKsHx4mQlyVihIv-pMbf.png)

Una red privada permite configurar el descubrimiento de equipos y el uso compartido de archivos en una LAN de confianza.

## **Comprobación de los discos**

Abre PowerShell como administrador:

`Get-Disk | Format-Table Number,FriendlyName,SerialNumber,PartitionStyle,Size`\
![](images\paste-F-zUzEsG8xdHqdSnjgZPM.png)

Resultado esperado:

- Disco del sistema: GPT (Tabla de particiones GUID). Es un **estilo de partición** de disco moderno. Es el "mapa" que le dice al sistema operativo cómo está dividido el disco físico en secciones lógicas (particiones, como la unidad C:, D:, etc.). Lo ves porque estás usando UEFI en tu máquina virtual de VirtualBox

- Tres discos adicionales: RAW. **No es un estilo de partición ni un sistema de archivos**. Significa que el disco físico virtual está ahí, conectado a la máquina, pero está **completamente vacío**. No tiene mapa de particiones (ni GPT ni MBR) y, por lo tanto, no tiene ningún sistema de archivos (como NTFS o FAT32).

## Comprueba ahora Storage Spaces:

`Get-PhysicalDisk | Format-Table FriendlyName, SerialNumber, CanPool, OperationalStatus, HealthStatus, Size`

![](images\paste-gq1P7TsP7ZggLYmcvsn3B.png)

Es normal que todos tengan el mismo FriendlyName, lo importante es que tengan números de serie o identificadores diferentes y que los tres discos adicionales muestren:

CanPool = True

## **Crear el grupo de almacenamiento**

Abre:

Administrador del servidor

→ Servicios de archivos y almacenamiento

→ Volúmenes

→ Grupos de almacenamiento

Selecciona el grupo:

Primordial

![](images\paste-uiEovgwv_RefHNT5Itk_7.png)

En la sección **Grupos de almacenamiento**\>Tareas:

→ Nuevo grupo de almacenamiento:

- Nombre: GRUPO-NAS

- Descripción: Discos destinados al almacenamiento del servidor NAS

Selecciona exclusivamente los tres discos de 20 GB.\
![](images\paste-xJzbUwa-za94rasYbibeq.png)

En la columna de asignación selecciona: Automático

**No** selecciones ningún disco como **reserva activa o Hot Spare**. Con solo tres discos, los tres son necesarios para crear el espacio de paridad.

Finaliza el asistente.

**Comprobación (en PowerShell) :**

`Get-StoragePool | Format-Table FriendlyName,HealthStatus,OperationalStatus,Size,AllocatedSize`

Debe aparecer:

- Primordial

- GRUPO-NAS

![](images\paste-u3Wy3-BEvjWaY2kmT46uI.png)

Microsoft establece este orden de trabajo: primero se agrupan los discos físicos, después se crea un disco virtual desde el grupo y, finalmente, se crea un volumen sobre el disco virtual.

## **Crear el disco virtual con paridad (equivalente a RAID 5)**

Selecciona GRUPO-NAS.

En la sección **Discos virtuales**: Tareas\> Nuevo disco virtual

![](images\paste-uCOpeR5pFsJOTo7wxhwnb.png)

Configura:

| Opción                        | Valor             |
|:------------------------------|:------------------|
| **Nombre**                    | DISCO-VIRTUAL-NAS |
| **Diseño de almacenamiento**  | Paridad           |
| **Tipo de aprovisionamiento** | Fijo              |
| **Tamaño**                    | Tamaño máximo     |

![](images\paste-R_Aqh_fuBnYQPh7XixAUj.png)

Con tres discos de 20 GB, la capacidad bruta es de 60 GB decimales. La capacidad útil será inferior al equivalente de dos discos porque Windows reserva espacio para metadatos, caché y organización interna. No debe esperarse una cifra exacta de 40 GB.

![](images\paste-8-vHRX3UFRGy5E7nkq9GT.png)\
La configuración de paridad:

- Distribuye los datos entre los tres discos.

- Almacena información de paridad.

- Puede soportar el fallo de uno de los tres discos.

- Ofrece menos capacidad útil que la suma bruta de los discos.

- Es más adecuada para almacenamiento secuencial, archivos y copias que para cargas con muchas escrituras pequeñas.

Al terminar el disco virtual, deja marcada la opción: *Crear un volumen cuando se cierre este asistente*

![](images\paste-M6dKManox5pOiS9vR3KQ1.png)

### **Comprobación (en PowerShell)**

`Get-VirtualDisk |Format-Table FriendlyName,ResiliencySettingName,ProvisioningType,HealthStatus,Size,FootprintOnPool`

- FriendlyName : DISCO-VIRTUAL-NAS

- ResiliencySettingName : Parity

- ProvisioningType : Fixed

- HealthStatus : Healthy\
  ![](images\paste-ld5H8jqBou5CSG-kTHmAo.png)

### **Crear el volumen**

![](images\paste-yef636ocPvekRFqXt3B9-.png)

Configura:

| Opción                   | Valor             |
|:-------------------------|:------------------|
| **Disco**                | DISCO-VIRTUAL-NAS |
| **Tamaño**               | Máximo            |
| **Letra**                | N:                |
| **Sistema de archivos**  | NTFS              |
| **Unidad de asignación** | Predeterminada    |
| **Etiqueta**             | DATOS-NAS         |
| **Formato rápido**       | Activado          |

![](images\paste-b35oE_UYoX0gbV6xTSiEH.png)

Utilizaremos NTFS porque esta práctica está centrada en permisos, herencia, listas de control de acceso y recursos compartidos SMB.

![](images\paste-4PnY2_EVlUPOjIod9PdMw.png)\
Comprueba el resultado en la shell: `Get-Volume -DriveLetter N`

![](images\paste-WyiXjZ_0DQa6zv6ZLTz7N.png)

## **Crear usuarios y grupos locales**

Las cuentas locales pertenecen exclusivamente al servidor en el que se crean. En este caso, los usuarios de SRV-NAS01 solo tendrán derechos en SRV-NAS01.

Abre: Win + R \> `lusrmgr.msc`\
![](images\paste-I5WI33yQhoYfIYB8s0sXT.png)

`Win + R > lusrmgr.msc` es un comando que abre la herramienta **Usuarios y grupos locales** en Windows. Esta herramienta te permite administrar usuarios y grupos en tu computadora, lo cual es útil para:

- **Crear nuevos usuarios:** Puedes agregar nuevos usuarios a tu computadora y asignarles permisos específicos.

- **Administrar usuarios existentes:** Puedes cambiar las contraseñas de los usuarios, habilitar o deshabilitar cuentas, y modificar sus pertenencias a grupos.

- **Crear nuevos grupos:** Puedes crear grupos para organizar a los usuarios y asignarles permisos colectivos.

- **Administrar grupos existentes:** Puedes agregar o quitar usuarios de los grupos y modificar sus permisos.

**Cómo usar `Win + R > lusrmgr.msc`:**

1.  Presiona la tecla **Windows** + **R** para abrir el cuadro de diálogo Ejecutar.

2.  Escribe `lusrmgr.msc` y presiona **Enter**.

3.  Se abrirá la herramienta **Usuarios y grupos locales**.

**Nota:** Esta herramienta solo está disponible en las ediciones Pro y Enterprise de Windows. No está disponible en las ediciones Home.

**Usuarios locales**

![](images\paste-By5QYG7l5oXw9mMNzmJpT.png)

Crea, como mínimo:

![](images\paste-e-STJ-v2axCkvwoLzR9kz.png)

- director01
- profesor01
- profesor02
- alumno01
- alumno02

En una práctica de laboratorio puede desmarcarse *El usuario debe cambiar la contraseña en el siguiente inicio de sesión,* y puede marcarse: *La contraseña nunca expira*

![](images\paste-n5TMeiWVfuDYisCYfh1pU.png)

Esto se hace únicamente para evitar interrupciones durante la práctica. No es una recomendación para un entorno real o en producción 

**Grupos locales**

![](images\paste-5_gBU3YbB9ejKQPjYSsXt.png)

Crea estos grupos y añádeles los usuarios que has creados antes

- NAS_DIRECCION

- NAS_PROFESORES

- NAS_ALUMNOS

**Pertenencia a grupos**

Configura:

| Usuario        | Grupo          |
|:---------------|:---------------|
| **director01** | NAS_DIRECCION  |
| **profesor01** | NAS_PROFESORES |
| **profesor02** | NAS_PROFESORES |
| **alumno01**   | NAS_ALUMNOS    |
| **alumno02**   | NAS_ALUMNOS    |

![](images\paste-2TMUHbL1Yjov-iaFGsrL4.png)

No asignaremos permisos directamente a los usuarios. Los permisos se asignarán a los grupos.

## **Crear la estructura de carpetas**

Crea:

- N:\\NAS

- N:\\NAS\\DIRECCION

- N:\\NAS\\PROFESORES

- N:\\NAS\\ALUMNOS

- N:\\NAS\\COMUN

# **Configurar los niveles de permisos**

Cuando un usuario accede por red intervienen dos controles diferentes.

**Permisos de Seguridad o NTFS**

Se configuran en Propiedades de la carpeta

→ Seguridad

Se aplican:

- Cuando se accede localmente.

- Cuando se accede por red.

- A carpetas, subcarpetas y archivos.

**Permisos de Compartir**

Se configuran en Propiedades de la carpeta

→ Compartir

→ Uso compartido avanzado

→ Permisos

Solo se aplican cuando se accede mediante la red SMB.

**Permiso efectivo**

Cuando se accede por red se aplican ambos niveles. El usuario obtiene **la combinación más restrictiva**.

| Compartir         | NTFS          | Resultado por red |
|:------------------|:--------------|:------------------|
| **Control total** | Modificar     | Modificar         |
| **Leer**          | Modificar     | Solo lectura      |
| **Cambiar**       | Control total | Cambiar           |
| **Cambiar**       | Modificar     | Modificar/Cambiar |

Por este motivo hay que revisar siempre las dos pestañas.

## **Configurar la herencia correctamente**

### **Preparar la carpeta raíz**

Abre las propiedades de: N:\\NAS

Accede a: Seguridad → Opciones avanzadas → Deshabilitar herencia

![](images\paste-bjwUHm9lm4rD5jFxy3QnP.png)

Windows mostrará dos opciones:

- **Convertir los permisos heredados en permisos explícitos:** Copia los permisos actuales y deja de heredarlos. Es la opción más segura para esta práctica porque mantiene inicialmente el acceso administrativo.

- **Quitar todos los permisos heredados:** Elimina directamente los permisos heredados. Puede provocar que se pierda el acceso a la carpeta si no se añaden inmediatamente permisos correctos.

Selecciona:

`Convertir los permisos heredados en permisos explícitos`

En N:\\NAS, deja únicamente:

| Principal           | Permiso       | Se aplica a                          |
|:--------------------|:--------------|:-------------------------------------|
| **SYSTEM**          | Control total | Esta carpeta, subcarpetas y archivos |
| **Administradores** | Control total | Esta carpeta, subcarpetas y archivos |

Elimina de esta carpeta raíz las entradas generales que puedan aparecer, como:

- Usuarios

- Usuarios autenticados

- CREATOR OWNER

![](images\paste-7o7jGR46NCDC9Oad362yc.png)

Las carpetas que se creen dentro heredarán los permisos de SYSTEM y Administradores. La herencia hace que las subcarpetas y archivos reciban automáticamente las entradas heredables del directorio padre. Windows permite deshabilitarla conservando las entradas como explícitas o eliminando únicamente las heredadas.

## **Configurar los permisos NTFS**

1.  En cada subcarpeta entra en: Propiedades → Seguridad → Editar → Agregar

2.  Pulsa **Ubicaciones** y selecciona el servidor local: *SRV-NAS01*

![](images\paste-UYLeZ2pzRP2b9QZSh4D88.png)

3.  **Carpeta DIRECCION** Agrega: SRV-NAS01\\NAS_DIRECCION

![](images\paste-aiATV-Ora-sxEwKbB-yda.png)

Concede: Modificar

![](images\paste--ueet7x0rE116gQOdXvKm.png)

Debe aplicarse a Esta carpeta, subcarpetas y archivos, esta es la configuración por defecto, pero si quieres comprobarlo puedes verlo en *Seguridad* \> *Opciones avanzadas*\
![](images\paste-kTpxlGXOCXxv5KcM4U90L.png)

4.  **Carpeta PROFESORES**

Agrega: *SRV-NAS01\\NAS_PROFESORES*

Concede: *Modificar*

5.  **Carpeta ALUMNOS**

Agrega: SRV-NAS01\\NAS_ALUMNOS

Concede: Modificar

**15.4 Carpeta COMUN**

Agrega:

*SRV-NAS01\\NAS_DIRECCION*

*SRV-NAS01\\NAS_PROFESORES*

*SRV-NAS01\\NAS_ALUMNOS*

Concede a los tres grupos: *Modificar*

**Resultado final de Seguridad**

| Carpeta        | Grupo autorizado | Permiso NTFS  |
|:---------------|:-----------------|:--------------|
| **DIRECCION**  | NAS_DIRECCION    | Modificar     |
| **PROFESORES** | NAS_PROFESORES   | Modificar     |
| **ALUMNOS**    | NAS_ALUMNOS      | Modificar     |
| **COMUN**      | Los tres grupos  | Modificar     |
| **Todas**      | Administradores  | Control total |
| **Todas**      | SYSTEM           | Control total |

No utilices Denegar. En esta práctica basta con no conceder acceso a los grupos no autorizados. Los permisos explícitos de denegación complican el cálculo de permisos efectivos y pueden afectar a usuarios que pertenezcan a varios grupos.

## **Crear los recursos compartidos**

En cada carpeta: Propiedades → Compartir → Uso compartido avanzado\>Marca: Compartir esta carpeta

![](images\paste-3Ez15rH92qO9u3lTz7vmY.png)

### **Comprobar los recursos y permisos**

**Recursos compartidos:** Get-SmbShare \| Format-Table Name, Path, Description\
![](images\paste-IgaC-5V_kl3qCTCIz0m3n.png)

**Permisos de un recurso:** Get-SmbShareAccess -Name PROFESORES

![](images\paste-HIkMtXWtne6t4F1vc4ohu.png)

**Permisos NTFS**

icacls N:\\NAS\\PROFESORES

![](images\paste-3IXiDAy_2ZqyFdyPM_Gig.png)

Debe aparecer el grupo NAS_PROFESORES con permiso de modificación.

## **Firewall SMB**

Windows Server 2025 utiliza reglas más restrictivas al crear recursos compartidos y abre únicamente los puertos necesarios para SMB moderno. El acceso normal utiliza TCP 445.

Desde un cliente comprueba: `Test-NetConnection 10.0.20.46 -Port 445`

![](images\paste-vhEZow1EmvMCImVYmDdMn.png)

Resultado esperado: TcpTestSucceeded : True. Si devuelve False, revisa:

Firewall de Windows Defender → Configuración avanzada → Reglas de entrada → Uso compartido de archivos e impresoras (SMB-In)

## **Resolución del nombre del servidor**

Los servidores DNS:

8.8.8.8

1.1.1.1

resuelven nombres públicos de Internet, pero no conocen nombres locales como:

SRV-NAS01

Por tanto, hay dos alternativas.

**Alternativa sencilla: utilizar la dirección IP**

\\\\192.168.50.107\\PROFESORES

**Alternativa por nombre**

Añadir en el equipo cliente una entrada en:

C:\\Windows\\System32\\drivers\\etc\\hosts

Ejemplo:

192.168.50.107 SRV-NAS01

Después podrá utilizarse:

\\\\SRV-NAS01\\PROFESORES

Durante toda la prueba debe utilizarse siempre el mismo identificador: o la IP o el nombre.

**20. Probar el acceso desde un equipo cliente**

**20.1 Profesor**

Desde CMD:

net use Z: \\\\192.168.50.107\\PROFESORES /user:SRV-NAS01\\profesor01 \*

El asterisco solicita la contraseña sin mostrarla.

El usuario deberá poder:

- Acceder a PROFESORES.

- Crear carpetas.

- Crear archivos.

- Modificar archivos.

- Eliminar archivos.

- Acceder a COMUN.

No deberá poder acceder a:

DIRECCION

ALUMNOS

**20.2 Alumno**

Primero elimina la conexión anterior:

net use \* /delete /y

Cierra también todas las ventanas del Explorador abiertas contra el NAS.

Conecta como alumno:

net use Z: \\\\192.168.50.107\\ALUMNOS /user:SRV-NAS01\\alumno01 \*

**20.3 Dirección**

net use Z: \\\\192.168.50.107\\DIRECCION /user:SRV-NAS01\\director01 \*

**21. Cambio de usuario SMB**

Windows no permite normalmente mantener, dentro de la misma sesión de Windows, conexiones contra el mismo servidor utilizando usuarios diferentes. Este comportamiento es intencionado.

Para cambiar de usuario:

1.  Cierra todas las ventanas del Explorador abiertas contra el NAS.

2.  Ejecuta:

net use \* /delete /y

3.  Comprueba:

Get-SmbConnection

4.  Si existen credenciales guardadas:

cmdkey /list

Elimina la correspondiente al servidor o a su IP:

cmdkey /delete:192.168.50.107

5.  Conecta con el usuario nuevo.

Si todavía se conserva una sesión, la opción más fiable para una práctica es:

Cerrar sesión en el equipo cliente

→ Volver a iniciar sesión

→ Conectar con el siguiente usuario

No deben probarse simultáneamente dos usuarios diferentes contra el mismo nombre o dirección del NAS. Cada prueba debe realizarse de forma independiente.

**22. Matriz final de comprobación**

| Usuario           | DIRECCION     | PROFESORES    | ALUMNOS       | COMUN         |
|:--------------|:--------------|:--------------|:--------------|:--------------|
| **director01**    | Modificar     | Denegado      | Denegado      | Modificar     |
| **profesor01**    | Denegado      | Modificar     | Denegado      | Modificar     |
| **profesor02**    | Denegado      | Modificar     | Denegado      | Modificar     |
| **alumno01**      | Denegado      | Denegado      | Modificar     | Modificar     |
| **alumno02**      | Denegado      | Denegado      | Modificar     | Modificar     |
| **Administrador** | Control total | Control total | Control total | Control total |

La palabra **Denegado** en esta tabla significa que no se le ha concedido acceso. No significa que hayamos creado una entrada explícita de tipo Denegar.

**23. Resultado final esperado**

La infraestructura deberá quedar así:

![](data:image/png;base64,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)

Con este diseño quedan claramente separados:

- El disco del sistema.

- Los discos físicos de almacenamiento.

- El grupo de almacenamiento.

- El disco virtual de paridad.

- El volumen NTFS.

- Los permisos NTFS.

- Los permisos SMB.

- La pertenencia de usuarios a grupos.

- La herencia de permisos.

- La autenticación desde los clientes.

**24. Simulación del fallo y sustitución de un disco del espacio de paridad**

En esta parte comprobaremos que el espacio de paridad continúa funcionando cuando se pierde uno de sus tres discos físicos y aprenderemos a sustituirlo por uno nuevo.

**Importante:** no se debe desconectar el disco NVMe de 60 GB que contiene Windows Server. Se desconectará únicamente uno de los tres discos de 20 GB pertenecientes a GRUPO-NAS.

En este laboratorio no vamos a corromper manualmente el archivo VDI. Simularemos una avería desconectando uno de los discos de datos de la controladora NVMe. De esta forma, Windows Server interpretará que ha perdido la comunicación con uno de los discos.

Un espacio de paridad con tres discos puede soportar el fallo de **un único disco**. Mientras permanezca degradado no debe desconectarse un segundo disco, porque el espacio podría quedar inaccesible y producirse una pérdida de datos. Microsoft describe los estados Degraded e Incomplete como situaciones en las que se ha reducido la resistencia, aunque los datos todavía pueden continuar accesibles.

**24.1 Identificar claramente los discos virtuales**

Para facilitar esta prueba, los archivos VDI deberían tener nombres diferentes:

SRV-NASxx-SO.vdi 60 GB

SRV-NASxx-DATOS1.vdi 20 GB

SRV-NASxx-DATOS2.vdi 20 GB

SRV-NASxx-DATOS3.vdi 20 GB

Esto evita desconectar accidentalmente el disco del sistema operativo.

Desde PowerShell, comprueba los discos pertenecientes al grupo:

Get-StoragePool -FriendlyName "GRUPO-NAS" \|

Get-PhysicalDisk \|

Format-Table DeviceId,SerialNumber,UniqueId,OperationalStatus,HealthStatus,Usage,Size

Anota o captura el resultado. Aunque todos puedan tener el mismo nombre:

ORCL-VBOX-NVME-VER12

sus valores SerialNumber y UniqueId deben ser distintos.

**24.2 Preparar datos para comprobar su integridad**

Antes de provocar el fallo, crea un archivo de prueba de 100 MB:

fsutil file createnew N:\\NAS\\COMUN\\PRUEBA-PARIDAD.bin 104857600

Crea también un archivo de texto:

"Archivo creado antes de simular el fallo del disco." \|

Set-Content "N:\\NAS\\COMUN\\ANTES-DEL-FALLO.txt"

Calcula el hash SHA-256 del archivo binario:

Get-FileHash "N:\\NAS\\COMUN\\PRUEBA-PARIDAD.bin" -Algorithm SHA256

Guarda el resultado. El hash nos permitirá comprobar que el archivo no cambia después del fallo y la reparación.

**Ejemplo:**

Algorithm : SHA256

Hash : 8A7C...

Path : N:\\NAS\\COMUN\\PRUEBA-PARIDAD.bin

También conviene comprobar desde un equipo cliente que el recurso es accesible:

\\\\192.168.50.xxx\\COMUN

**24.3 Comprobar el estado inicial**

Antes de desconectar ningún disco, ejecuta:

Get-StoragePool -FriendlyName "GRUPO-NAS" \|

Format-Table FriendlyName,OperationalStatus,HealthStatus,Size,AllocatedSize

Get-VirtualDisk -FriendlyName "DISCO-VIRTUAL-NAS" \|

Format-Table FriendlyName,ResiliencySettingName,OperationalStatus,HealthStatus

Get-Volume -DriveLetter N \|

Format-Table DriveLetter,FileSystemLabel,FileSystem,HealthStatus,OperationalStatus,SizeRemaining,Size

Resultado esperado:

| Elemento                | Estado esperado |
|:------------------------|:----------------|
| **GRUPO-NAS**           | Healthy / OK    |
| **DISCO-VIRTUAL-NAS**   | Healthy / OK    |
| **Volumen D:**          | Healthy / OK    |
| **Tres discos físicos** | Healthy / OK    |

**24.4 Simular la avería de un disco**

Apaga correctamente Windows Server:

Stop-Computer

Espera hasta que VirtualBox muestre la máquina como completamente apagada.

En el equipo anfitrión:

**VirtualBox**

→ Seleccionar **WS25 UEFI**

→ Configuración

→ Almacenamiento

→ Controladora NVMe

Selecciona uno de los discos de datos, por ejemplo:

SRV-NASxx-DATOS2.vdi

Pulsa **Quitar el dispositivo seleccionado de la controladora**.

No selecciones:

SRV-NASxx-SO.vdi

Cuando VirtualBox pregunte qué hacer con el disco:

- Desconéctalo de la máquina virtual.

- Conserva el archivo VDI.

- No lo elimines todavía del disco del anfitrión.

La controladora NVMe deberá quedar temporalmente así:

Controladora NVMe

├── SRV-NASxx-SO.vdi

├── SRV-NASxx-DATOS1.vdi

└── SRV-NASxx-DATOS3.vdi

Inicia nuevamente la máquina virtual.

**24.5 Comprobar el estado degradado**

Abre PowerShell como administrador y ejecuta:

Get-StoragePool -FriendlyName "GRUPO-NAS" \|

Get-PhysicalDisk \|

Format-Table DeviceId,SerialNumber,UniqueId,OperationalStatus,HealthStatus,Usage,Size

El disco desconectado puede mostrar estados semejantes a:

OperationalStatus : Lost Communication

HealthStatus : Warning

La descripción exacta puede variar, pero uno de los discos debe aparecer como ausente, sin comunicación o no saludable.

Comprueba el grupo:

Get-StoragePool -FriendlyName "GRUPO-NAS" \|

Format-Table FriendlyName,OperationalStatus,HealthStatus,IsReadOnly

Comprueba el disco virtual:

Get-VirtualDisk -FriendlyName "DISCO-VIRTUAL-NAS" \|

Format-Table FriendlyName,OperationalStatus,HealthStatus,DetachedReason

Los estados más habituales serán:

HealthStatus : Warning

OperationalStatus : Degraded

o:

OperationalStatus : Incomplete

Esto no significa necesariamente que los datos se hayan perdido. Significa que el espacio ha perdido su tolerancia a fallos y necesita que se sustituya el disco. En un servidor independiente, Microsoft indica que, después de conectar el reemplazo, debe utilizarse Repair-VirtualDisk para restaurar la resistencia.

**24.6 Comprobar que los datos continúan disponibles**

Comprueba que el volumen sigue montado:

Get-Volume -DriveLetter N

Comprueba que el archivo existe:

Test-Path "N:\\NAS\\COMUN\\PRUEBA-PARIDAD.bin"

Resultado esperado: True

Vuelve a calcular su hash:

Get-FileHash "N:\\NAS\\COMUN\\PRUEBA-PARIDAD.bin" -Algorithm SHA256

El hash debe coincidir exactamente con el obtenido antes de desconectar el disco.

Crea un archivo mientras el espacio está degradado:

"El espacio de paridad continúa funcionando con un disco ausente." \|

Set-Content "N:\\NAS\\COMUN\\CREADO-DURANTE-EL-FALLO.txt"

Desde el equipo cliente:

1.  Accede al recurso COMUN.

2.  Abre ANTES-DEL-FALLO.txt.

3.  Comprueba que aparece CREADO-DURANTE-EL-FALLO.txt.

4.  Crea un archivo nuevo desde la red.

5.  Modifica y elimina ese archivo.

Utiliza el mismo usuario SMB con el que ya estabas conectado. No cambies de usuario durante esta comprobación para evitar que Windows reutilice credenciales anteriores.

**Resultado esperado**

Aunque haya desaparecido uno de los discos:

- El volumen D: continúa accesible.

- Los archivos existentes se pueden leer.

- Se pueden crear y modificar archivos.

- Los recursos SMB siguen disponibles.

- El estado del almacenamiento aparece como degradado.

- Ya no existe protección frente al fallo de otro disco.

**25. Sustitución del disco averiado**

**25.1 Crear el disco de reemplazo**

Apaga nuevamente la máquina virtual:

Stop-Computer

En VirtualBox crea un nuevo disco:

| Propiedad      | Valor                   |
|:---------------|:------------------------|
| **Tipo**       | VDI                     |
| **Asignación** | Reservado dinámicamente |
| **Tamaño**     | 20 GB                   |
| **Nombre**     | SRV-NASxx-REEMPLAZO.vdi |

Conecta el disco nuevo a la misma controladora NVMe, utilizando el puerto que ha quedado libre:

Controladora NVMe

├── SRV-NASxx-SO.vdi

├── SRV-NASxx-DATOS1.vdi

├── SRV-NASxx-DATOS3.vdi

└── SRV-NASxx-REEMPLAZO.vdi

Los ajustes especiales de NVMe aplicados mediante VBoxManage permanecen asociados a la máquina virtual. No es necesario repetirlos mientras no se elimine y vuelva a crear la controladora NVMe.

Inicia Windows Server.

**25.2 Comprobar el disco nuevo**

Ejecuta:

Get-PhysicalDisk \|

Format-Table DeviceId,FriendlyName,SerialNumber,UniqueId,CanPool,OperationalStatus,HealthStatus,Size

El disco nuevo debe mostrar:

CanPool : True

OperationalStatus : OK

HealthStatus : Healthy

También puedes mostrar exclusivamente los discos disponibles:

Get-PhysicalDisk -CanPool \$true

Debería aparecer un único disco de aproximadamente 20 GB.

No inicialices el disco desde Administración de discos, no crees particiones y no lo formatees.

Si aparece CanPool=False, consulta el motivo:

Get-PhysicalDisk \|

Select-Object FriendlyName,SerialNumber,UniqueId,CanPool,CannotPoolReason

**25.3 Agregar el disco de reemplazo al grupo**

Abre:

Administrador del servidor

→ Servicios de archivos y almacenamiento

→ Volúmenes

→ Grupos de almacenamiento

Selecciona:

GRUPO-NAS

En la sección **Discos físicos**:

TAREAS

→ Agregar disco físico

Selecciona:

SRV-NASxx-REEMPLAZO.vdi

En **Asignación**, selecciona:

Automático

No lo configures como reserva activa.

Pulsa **Aceptar**.

Microsoft permite agregar el nuevo disco desde el Administrador del servidor o mediante Add-PhysicalDisk. El disco debe encontrarse en el grupo primordial y mostrar CanPool=True.

**Alternativa mediante PowerShell**

\$Pool = Get-StoragePool -FriendlyName "GRUPO-NAS"

\$NuevoDisco = Get-PhysicalDisk -CanPool \$true

Add-PhysicalDisk \`

-StoragePool \$Pool \`

-PhysicalDisks \$NuevoDisco \`

-Usage AutoSelect

Comprueba el resultado:

Get-StoragePool -FriendlyName "GRUPO-NAS" \|

Get-PhysicalDisk \|

Format-Table DeviceId,SerialNumber,UniqueId,OperationalStatus,HealthStatus,Usage,Size

En este momento aparecerán:

- Dos discos originales saludables.

- El nuevo disco saludable.

- La referencia al disco ausente o averiado.

**25.4 Identificar el disco averiado**

Ejecuta:

Get-StoragePool -FriendlyName "GRUPO-NAS" \|

Get-PhysicalDisk \|

Format-Table DeviceId,SerialNumber,UniqueId,OperationalStatus,HealthStatus,Usage,VirtualDiskFootprint

Localiza el disco cuyo estado no sea correcto y copia su UniqueId.

Ejemplo conceptual:

UniqueId : ID-DEL-DISCO-AVERIADO

OperationalStatus : Lost Communication

HealthStatus : Warning

Usage : Retired

El disco puede haber sido marcado automáticamente como Retired.

Si todavía aparece como Auto-Select, retíralo lógicamente utilizando su identificador:

Set-PhysicalDisk \`

-UniqueId "ID-DEL-DISCO-AVERIADO" \`

-Usage Retired

No copies literalmente ID-DEL-DISCO-AVERIADO: debe sustituirse por el UniqueId real mostrado en el servidor.

La marca Retired indica que Storage Spaces debe dejar de utilizar ese disco y mover o reconstruir sus datos sobre otros discos disponibles.

**25.5 Reparar el disco virtual**

Inicia la reparación:

Repair-VirtualDisk -FriendlyName "DISCO-VIRTUAL-NAS"

Comprueba el trabajo:

Get-StorageJob

Mientras se está reparando puede aparecer información similar a:

Name : Repair

JobState : Running

PercentComplete : 42

Repite el comando hasta que finalice:

Get-StorageJob

Como los discos utilizados en la práctica son pequeños, es posible que la reparación finalice tan rápidamente que Get-StorageJob no llegue a mostrar ningún trabajo activo.

Durante la reparación, el disco virtual puede mostrar:

OperationalStatus : In Service

HealthStatus : Warning

Microsoft recomienda reparar el disco virtual, esperar a que termine el trabajo y comprobar después que el almacenamiento vuelva a un estado saludable.

**25.6 Comprobar que la reparación ha terminado**

Ejecuta:

Get-VirtualDisk -FriendlyName "DISCO-VIRTUAL-NAS" \|

Format-Table FriendlyName,ResiliencySettingName,OperationalStatus,HealthStatus,Size

Resultado esperado:

OperationalStatus : OK

HealthStatus : Healthy

Comprueba el grupo:

Get-StoragePool -FriendlyName "GRUPO-NAS" \|

Format-Table FriendlyName,OperationalStatus,HealthStatus,Size,AllocatedSize

Comprueba el volumen:

Get-Volume -DriveLetter N \|

Format-Table DriveLetter,FileSystemLabel,HealthStatus,OperationalStatus,SizeRemaining,Size

Resultado esperado:

| Elemento               | Resultado                  |
|:-----------------------|:---------------------------|
| **Grupo GRUPO-NAS**    | Healthy                    |
| **Disco virtual**      | Healthy                    |
| **Volumen D:**         | Healthy                    |
| **Disco de reemplazo** | Healthy                    |
| **Disco antiguo**      | Retired o sin comunicación |

**25.7 Verificar que el disco antiguo ya no contiene datos**

Ejecuta:

Get-StoragePool -FriendlyName "GRUPO-NAS" \|

Get-PhysicalDisk \|

Select-Object DeviceId,SerialNumber,UniqueId,Usage,OperationalStatus,HealthStatus,VirtualDiskFootprint

El disco averiado debería mostrar:

Usage : Retired

VirtualDiskFootprint : 0

VirtualDiskFootprint=0 significa que el disco virtual ya no depende del disco retirado. Microsoft recomienda comprobar este valor antes de eliminar definitivamente el disco del grupo.

**25.8 Eliminar la referencia al disco averiado**

Recupera el objeto correspondiente mediante su UniqueId:

\$Pool = Get-StoragePool -FriendlyName "GRUPO-NAS"

\$DiscoAveriado = Get-PhysicalDisk \`

-UniqueId "ID-DEL-DISCO-AVERIADO"

Elimínalo del grupo:

Remove-PhysicalDisk \`

-StoragePool \$Pool \`

-PhysicalDisks \$DiscoAveriado

Confirma la operación cuando PowerShell lo solicite.

Remove-PhysicalDisk elimina el disco físico indicado de la configuración del grupo. Antes de utilizarlo debe existir capacidad suficiente para mantener la resistencia del disco virtual.

No ejecutes:

Remove-VirtualDisk

Ese comando eliminaría DISCO-VIRTUAL-NAS, el volumen y los datos almacenados.

**25.9 Comprobación definitiva**

Ejecuta:

Get-StoragePool -FriendlyName "GRUPO-NAS" \|

Get-PhysicalDisk \|

Format-Table DeviceId,SerialNumber,UniqueId,OperationalStatus,HealthStatus,Usage,Size

Deben quedar exactamente tres discos saludables dentro de GRUPO-NAS:

- Dos discos originales.

- Un disco de reemplazo.

Comprueba todos los niveles:

Get-StoragePool -FriendlyName "GRUPO-NAS"

Get-VirtualDisk -FriendlyName "DISCO-VIRTUAL-NAS"

Get-Volume -DriveLetter N

Vuelve a calcular el hash:

Get-FileHash "N:\\NAS\\COMUN\\PRUEBA-PARIDAD.bin" -Algorithm SHA256

Debe coincidir con los dos hashes anteriores.

Comprueba también:

Get-Content "N:\\NAS\\COMUN\\ANTES-DEL-FALLO.txt"

Get-Content "N:\\NAS\\COMUN\\CREADO-DURANTE-EL-FALLO.txt"

Finalmente, desde el cliente vuelve a probar los recursos:

\\\\192.168.50.xxx\\DIRECCION

\\\\192.168.50.xxx\\PROFESORES

\\\\192.168.50.xxx\\ALUMNOS

\\\\192.168.50.xxx\\COMUN

Los usuarios deben conservar exactamente los mismos permisos que antes del fallo.

**26. Eliminar definitivamente el antiguo VDI**

Cuando se haya comprobado que:

- GRUPO-NAS está saludable.

- DISCO-VIRTUAL-NAS está saludable.

- El volumen N: funciona.

- Los hashes coinciden.

- Los recursos SMB son accesibles.

- El disco antiguo ya no aparece dentro del grupo.

Puede eliminarse el VDI averiado desde el anfitrión:

VirtualBox

→ Herramientas

→ Medios

→ Discos duros

Selecciona el antiguo disco desconectado y elimínalo.

No elimines ninguno de los tres discos que actualmente aparecen como saludables dentro de GRUPO-NAS.

**27. Resumen de estados esperados**

| Momento | Grupo | Disco virtual | Volumen N: | Recursos SMB |
|:--------------|:--------------|:--------------|:--------------|:--------------|
| **Antes del fallo** | Healthy | Healthy | Disponible | Disponibles |
| **Con un disco ausente** | Warning | Degraded o Incomplete | Disponible | Disponibles |
| **Durante la reparación** | Warning/In Service | In Service | Disponible | Disponibles |
| **Después de reparar** | Healthy | Healthy | Disponible | Disponibles |

**Conclusión de la prueba**

La práctica demuestra que:

- La paridad distribuye datos e información de recuperación entre los discos.

- El fallo de un disco no provoca inmediatamente la pérdida del volumen.

- El servidor puede continuar ofreciendo los recursos SMB.

- Durante el estado degradado no existe protección frente a un segundo fallo.

- El disco debe sustituirse lo antes posible.

- Agregar el disco nuevo no es suficiente: hay que reparar el disco virtual.

- El disco averiado solo debe eliminarse del grupo después de que la reparación termine y su VirtualDiskFootprint sea 0.

- La paridad mejora la disponibilidad, pero **no sustituye a una copia de seguridad**.