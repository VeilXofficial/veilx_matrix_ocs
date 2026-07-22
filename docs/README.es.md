<div align="center">

# Servidor de comunicación Matrix privado · Despliegue con un comando (edición tuwunel)

**Tu servidor, tus datos: un mensajero de equipo autoalojado, hecho para la confidencialidad y la soberanía de los datos.**

Con motor **tuwunel** (en Rust, base de datos integrada, **sin PostgreSQL**): más ligero, más estable y capaz de **enviar archivos grandes / fotos / videos largos como Telegram**. Con 2 GB de RAM funciona cómodo un equipo mediano. El cifrado de extremo a extremo, la minimización de metadatos y el registro solo por invitación están **activados por defecto**. Un solo comando para desplegar: no necesitas ser administrador de sistemas; cada opción viene explicada en lenguaje sencillo.

Cliente recomendado: **Element X**. Un cliente **VeilX** propio está en desarrollo (más pulido, más fácil, con más funciones; código abierto y auditable; equipo de operaciones en Reino Unido, Singapur y Japón). Archivos de clientes, contratos, discusiones internas, reuniones de voz y video: todo vive únicamente en tu propio servidor. Construido sobre el protocolo abierto [Matrix](https://matrix.org). Código público y auditable (gratis para uso no comercial).

[English](../README.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Русский](README.ru.md) · [Français](README.fr.md) · **Deutsch** · [Italiano](README.it.md) · [Español](README.es.md) · [Bahasa Melayu](README.ms.md) · [فارسی](README.fa.md)· [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [粵語](README.zh-HK.md) 

</div>

---

## ✨ Qué obtienes al instalar

- 💬 Chat de texto y salas de grupo (**cifrado de extremo a extremo: ni el servidor ni el proveedor de hosting pueden leer el contenido**)
- 📁 **Envía archivos grandes / fotos / videos largos** (límite por archivo de **4 GB** por defecto, configurable a más; esta es la función estrella)
- 📞 Llamadas de voz / video individuales y grupales (opcional)
- 📱 Registro desde el teléfono: instala **Element X**, escribe tu dominio, regístrate e inicia sesión (sin pasar por element.io)
- 🌐 Tu propio cliente web: abre `https://tu-dominio` en el navegador para registrarte/entrar, sin app
- 🖥️ **Panel de administración web gráfico** (Ketesa): gestiona usuarios, emite/revoca códigos de invitación, revisa salas y multimedia
- 🔒 **Endurecido para privacidad por defecto**: la IP real del cliente nunca se guarda, los borrados son permanentes, presencia desactivada, los registros no guardan IPs
- 👥 Solo por invitación: por defecto solo entra quien tiene un código de invitación
- ⚡ **Eficiente en recursos**: un solo proceso en Rust, sin PostgreSQL; 2 GB de RAM sirven a ~300 personas

---

## 📋 Antes de empezar (3 cosas)

| Qué | Requisito | Dónde |
|---|---|---|
| **Un servidor en la nube (VPS)** | Ubuntu 22.04 / 24.04 (o Debian 11+), con IP pública. **Elige la RAM según el tamaño del equipo** (ver abajo). **Provee disco suficiente si compartes archivos grandes.** | [Vultr](https://www.vultr.com), [DigitalOcean](https://www.digitalocean.com), [Hetzner](https://www.hetzner.com/cloud), [OVHcloud](https://www.ovhcloud.com) u otro que sea de tu confianza |
| **Un dominio** | Cualquier terminación (.com / .org / .net…) | [Namecheap](https://www.namecheap.com), [Porkbun](https://porkbun.com), [Cloudflare Registrar](https://www.cloudflare.com/products/registrar/) |
| **10 minutos** | Todo es copiar y pegar; no se programa nada | — |

> 💡 **Elige la RAM por usuarios activos simultáneos** (federación apagada, chat + archivos): **1 GB** ≈ unas decenas de personas (apaga las llamadas) · **2 GB** ≈ 300 personas · **4 GB / 2 vCPU** ≈ 500 personas. tuwunel es liviano; la CPU rara vez es el cuello de botella.
> 💡 **El disco es la variable real para archivos grandes.** El multimedia se guarda en el disco local del servidor y, al estar cifrado de extremo a extremo, no se puede deduplicar. Un uso intensivo puede sumar de cientos de GB a TB por mes. Usa un disco de sistema de ≥ 50–100 GB; para uso intensivo, provee un volumen grande o almacenamiento de objetos, y vigila la opción "Limpiar disco".
> 💡 **La jurisdicción importa para la privacidad.** Elige un proveedor y un país con los que te sientas cómodo: en principio, al host se le puede exigir cooperar. El cifrado E2E protege el *contenido* de todos modos, pero los metadatos viven en el host.
> 💡 Al contratar, elige siempre una imagen **Ubuntu 22.04 / 24.04**. Si la RAM es menor a 2,5 GB, el script agrega swap automáticamente.

---

## Paso 0 — Prepara el sistema operativo (omítelo si ya lo elegiste bien)

Solo se admite **Ubuntu 22.04 / 24.04** (o Debian 11+).

- **Servidor nuevo**: elige **Ubuntu 22.04 x86_64** (o 24.04) en el campo "SO / Image" al contratar.
- **SO equivocado**: usa "Reinstalar / Rebuild" del proveedor para instalar Ubuntu 22.04. ⚠️ Esto **borra todos los datos**; respalda primero un servidor existente.
- ¿No sabes qué corres? Tras conectarte (Paso 3), ejecuta `cat /etc/os-release`.
- Si instalas sobre el SO equivocado, el script lo detecta y te avisa claramente; no rompe nada.

---

## Paso 1 — Agrega registros DNS (~2 minutos)

En el panel DNS de tu **registrador de dominios**, agrega **registros A**.

Suponiendo dominio `mychat.org` e IP del servidor `1.2.3.4`:

| Tipo | Host (nombre) | Valor | Uso |
|---|---|---|---|
| A | `@` (dominio raíz) | `1.2.3.4` | Dominio raíz + cliente web + delegación |
| A | `matrix` | `1.2.3.4` | El servidor de mensajería |
| A | `admin` | `1.2.3.4` | Panel de administración (omítelo si va sin admin) |
| A | `livekit` | `1.2.3.4` | Llamadas (omítelo si van sin llamadas) |
| A | `matrix-rtc` | `1.2.3.4` | Llamadas (omítelo si van sin llamadas) |

> 📌 El campo host lleva solo el **prefijo** (`matrix`), no el dominio completo.
> 📌 Los registros propagan en 1–10 minutos; el instalador espera solo si aún no están activos.
> 📌 Para solo chat + archivos (sin llamadas) basta con `@` / `matrix` / `admin`.
> ⚠️ **¿Usas Cloudflare?** Estos registros deben estar en **nube gris (solo DNS)**; **no actives la nube naranja (proxy)**. El proxy ① limita los archivos grandes a 100 MB (Free/Pro) ② impide emitir el certificado ③ bloquea el medio de las llamadas. El instalador pregunta si usas un CDN (responde que sí para relajar la verificación DNS), pero el host `matrix` debe seguir en nube gris.

---

## Paso 2 — Abre puertos del firewall (~1 minuto)

En el "Security Group / Firewall" de tu proveedor, permite:

| Puerto | Protocolo | Uso |
|---|---|---|
| 80 | TCP | Emisión del certificado HTTPS |
| 443 | TCP + UDP | Web y tráfico cifrado |
| 7881 | TCP | Canal de respaldo de llamadas (omítelo sin llamadas) |
| **7882** | **UDP** | **Audio/video de las llamadas (¡el que más se olvida! Sin él = sin sonido ni imagen)** |

> 📌 ¿Tu proveedor no tiene esa capa de "security group"? Omítelo: el script configura el firewall del sistema automáticamente.

---

## Paso 3 — Conéctate a tu servidor (~1 minuto)

Abre una terminal (macOS: "Terminal"; Windows: "PowerShell"), ejecuta lo siguiente (cambia la IP) e ingresa la contraseña del servidor cuando la pida (**es normal que la pantalla no muestre caracteres al escribir la contraseña**):

```bash
ssh root@TU_IP_DEL_SERVIDOR
```

En la primera conexión, responde `yes` al aviso de huella.

> 📌 Si el usuario por defecto no es root (p. ej. `ubuntu`), usa `ssh ubuntu@IP`; el script eleva privilegios solo.

---

## Paso 4 — Ejecuta el instalador (~5–10 minutos, automático)

Ya conectado, **copia la línea completa** y pégala en la terminal:

```bash
sudo apt-get update && sudo apt-get install -y wget && wget -O tuwunel.sh https://raw.githubusercontent.com/VeilXofficial/veilx_matrix_ocs/main/matrix-tuwunel-installer.sh && sudo bash tuwunel.sh
```

Sigue el asistente. Pregunta **6 opciones + una pregunta de CDN**; cada una se explica en pantalla, así que ante la duda, presiona Enter (los valores por defecto son la combinación más segura):

| Opción | Enter (recomendado) | Notas |
|---|---|---|
| 1 Quién puede registrarse | **Requiere código de invitación** | Solo entra quien tiene tu código; el primero en registrarse queda como admin. (O totalmente abierto: no para uso empresarial.) |
| 2 Federación | **Apagada** | Modo isla: nadie de afuera puede escribir a tus miembros; mínima superficie de ataque. |
| 3 Llamadas de voz/video | **Apágalas primero** | Requiere dos registros DNS extra (`livekit`/`matrix-rtc`) y los puertos 7881/7882; primero estabiliza chat + archivos. |
| 4 Cliente web | **Encendido** | Los miembros abren `https://tu-dominio` para registrarse/entrar, sin app. |
| 5 Panel de administración | **Encendido** | Un panel gráfico (Ketesa) en `admin.tu-dominio`. |
| 6 Tamaño máximo de archivo | **4 GB** | Pon lo que quieras (p. ej. 10 GB); a mayor tamaño, más disco. |
| ＋ ¿Detrás de Cloudflare/CDN? | **No** | Responde sí solo si usas un CDN (relaja la verificación DNS); `matrix` debe seguir en nube gris. |

> 🔒 **Activado automáticamente (no se pregunta; queda activo al instalar):** ① las salas nuevas quedan **forzadas a cifrado E2E** ② **minimización de metadatos** (IP real no guardada, borrados permanentes, presencia off, registros sin IP) ③ **auto-registro con Element X** (OIDC nativo; el registro sigue requiriendo código de invitación). Para desactivar el endurecimiento de metadatos: `PRIVACY=0 sudo -E tuwunel config`.
> 🤖 **Totalmente desatendido:** `REG_MODE=token ENABLE_CALLS=1 ENABLE_ADMIN=1 sudo -E bash tuwunel.sh mychat.org`

Luego corre solo: verifica DNS → instala Docker → ajusta el sistema → firewall → genera la configuración → arranca servicios → obtiene el certificado HTTPS → **crea el admin e imprime la cuenta/contraseña**.

El éxito se ve así:

```
========================================================
 🎉 ¡tuwunel desplegado!  mychat.org
 (registro[token] · federación[off] · llamadas[off] · web[on] · admin[on] · registro-móvil[on] · archivos-grandes[4G] · motor tuwunel/Rust, sin Postgres)

 Registro / inicio de sesión de miembros
   Web (recomendado): abre https://mychat.org para registrarte e iniciar sesión
   App móvil: instala Element X → servidor "mychat.org" → regístrate (código) o inicia sesión

 Admin (creado automáticamente)
   cuenta: admin    contraseña: xxxxxxxxxxxx
   Panel web: https://admin.mychat.org  (inicia sesión con la cuenta admin de arriba)

 Gestión diaria:  sudo tuwunel   (menú)    sudo tuwunel adduser   (agregar miembro)
========================================================
```

> 🔑 **¡Anota la cuenta/contraseña del admin y el código de invitación!** Todo queda en el servidor, en `/opt/tuwunel/CREDENTIALS.txt` (`cat /opt/tuwunel/CREDENTIALS.txt`).
> ⚠️ Un "aún no está listo" al final suele significar que el firewall de la nube no permite 80/443, o que el DNS no propagó globalmente. Caddy reintenta el certificado solo; no hay que reinstalar.

---

## Paso 5 — Inicia sesión desde el teléfono / la computadora

| Dispositivo | Cliente | Descarga |
|---|---|---|
| iPhone / iPad | **Element X** | [App Store](https://apps.apple.com/app/element-x/id1631335820) |
| Android | **Element X** | [Google Play](https://play.google.com/store/apps/details?id=io.element.android.x) |
| Windows / macOS / Linux | **Element Desktop** | [element.io/download](https://element.io/download) |
| Navegador (sin instalar) | Tu **propio cliente web** | Abre `https://tu-dominio` |

**Inicia sesión con el servidor = tu dominio** (p. ej. `mychat.org`, **no** `matrix.mychat.org`); usa la cuenta/contraseña que salió al final de la instalación.

> ⚠️ **¿No conecta / Element X dice "couldn't connect to this homeserver"? Lo primero: revisa que la fecha y hora del teléfono estén correctas.**
> Un reloj mal ajustado → el certificado HTTPS falla la validación → simplemente no conecta (muy común, sobre todo en Android).
> Solución: en el teléfono, **Ajustes → Fecha y hora → activa "Automática"**, y reintenta.

---

## 👥 Cómo se unen los miembros (elige una)

1. **El admin crea la cuenta (lo más controlado):** `sudo tuwunel adduser` crea un usuario y le pone contraseña en un comando; envíale "dominio + usuario + contraseña". El código de invitación nunca sale de tus manos.
2. **Reparte un código de invitación, auto-registro web:** envía el código (en `CREDENTIALS.txt`) + `https://tu-dominio`; los miembros se registran solos en el navegador.
3. **Reparte un código, auto-registro con Element X:** instalan Element X → escriben tu dominio → crean cuenta → ingresan el código.

---

## 🖥️ Panel de administración gráfico (Ketesa, recomendado)

Si lo activaste (opción 5), el instalador despliega un **panel de administración web gráfico**: se gestiona todo con el mouse, sin comandos.

**Cómo entrar:** ve a `https://admin.tu-dominio` → **inicia sesión directamente con la cuenta admin `admin` + contraseña** (sin una contraseña de portón aparte; el panel está bloqueado a tu servidor).

**Qué puedes hacer:** gestionar usuarios (crear/desactivar/restablecer contraseña), **emitir y revocar códigos de invitación**, revisar salas/multimedia, directorio de salas, tareas programadas.

> 📌 Las páginas "Reportes / Usuarios reportados" pueden dar error o salir vacías: tuwunel no implementa esa función; es **normal** y casi nunca la necesitarás.
> 📌 El panel requiere tuwunel v1.8.1+ (la imagen `:latest` ya lo trae). Si el login del panel falla: `cd /opt/tuwunel && docker compose pull tuwunel && docker compose up -d`.
> 📌 Agregar el panel a un servidor existente: `sudo tuwunel enable-admin` (agrega antes el registro DNS `admin`).

---

## 🔧 Gestión diaria: el menú

Tras instalar, **ejecutar `sudo tuwunel` abre el menú de gestión** (sin comandos que memorizar):

```bash
sudo tuwunel
```

```
┌──────────────────────────────────────────────┐
│  menú de gestión tuwunel   tu-dominio         │
└──────────────────────────────────────────────┘
  1) Estado                    6) Actualizar imágenes
  2) Agregar un miembro        7) Limpiar disco
  3) Cambiar configuración     8) Reiniciar servicios
  4) Activar/desactivar admin  9) Actualizar script + nuevas funciones
  5) Respaldar ahora          10) Desinstalar por completo
  p) Endurecimiento de privacidad / limpieza de metadatos
  s) Redactar el archivo de credenciales en texto plano (anti-forense)
  b) Respaldo cifrado automático programado
  0) Salir
```

O usa comandos directamente:

```bash
sudo tuwunel adduser          # agregar un miembro
sudo tuwunel config           # cambiar configuración (Enter = mantener; datos/cuentas intactos)
sudo tuwunel update           # traer el último script de GitHub y aplicar nuevas funciones (datos intactos)
sudo tuwunel enable-admin     # agregar el panel de administración a un servidor existente
sudo tuwunel enable-elementx  # activar el auto-registro con Element X
sudo tuwunel autobackup       # activar respaldos cifrados semanales automáticos
sudo tuwunel privacy          # privacidad/metadatos: ver qué se puede quitar, limpiar registros
sudo tuwunel forget-secrets   # anti-forense: redactar contraseña/código en texto plano en disco
sudo tuwunel uninstall        # desinstalar
```

> 🔄 **Reconfigura sin reinstalar** (menú 3): vuelve a preguntar las opciones, **Enter = mantener el valor actual**, y reinicia. Cuentas, historial y claves se conservan.

---

## 🔒 Privacidad / anti-forense (el foco de esta edición)

Este sistema está hecho para proteger comunicaciones confidenciales y **minimiza por defecto los rastros que quedan en el servidor**:

- ✅ **El contenido de los mensajes está cifrado de extremo a extremo**: ni tú (el operador) ni el proveedor de hosting pueden leerlo. Es la única garantía que se mantiene sin importar qué tan bueno o malo sea el servidor.
- ✅ **Minimización de metadatos (activada por defecto):** IP real del cliente nunca guardada (`ip_source`), **borrados verdaderamente permanentes** (sin retener el original 60 días), presencia off, nivel de log demasiado bajo para registrar IPs, exposición de perfiles/directorio de salas más estricta.
- ✅ **Herramientas anti-forense:** `sudo tuwunel forget-secrets` redacta la contraseña/código en texto plano en disco; `sudo tuwunel autobackup` produce respaldos cifrados con AES-256.

**Los límites honestos (dilos a tus clientes; no prometas de más):**

- ❌ **Metadatos que no se pueden eliminar:** membresía de salas, línea de tiempo de eventos, existencia de la cuenta, nombres de salas / archivos. El servidor debe conservarlos para funcionar. El E2E protege el *contenido*, **no los metadatos** (quién habla con quién, cuándo, nombres de salas, nombres de archivos).
- ❌ **Si el disco es incautado / clonado físicamente:** en un VPS común los datos se escriben en texto plano en disco y los metadatos pueden extraerse con análisis forense. Defender esta capa requiere un proveedor/jurisdicción de confianza, o cifrado de disco completo avanzado / un proxy "escudo" al frente (no automático; requiere trabajo de ingeniería).
- ❌ **Ocultar la IP del servidor con Cloudflare no funciona de verdad** (los logs de transparencia de certificados y los subdominios en nube gris la filtran). Ocultar la IP de verdad requiere un proxy WireGuard autoalojado al frente.

> Redacción precisa para clientes: **"El contenido de los mensajes y los adjuntos están cifrados de extremo a extremo; el operador no puede leerlos. El servidor conserva metadatos de comunicación (quién está en qué sala, cuándo, nombres de archivos, nombres de salas), que podrían extraerse si el servidor es incautado físicamente."**

---

## 💾 Respaldos (muy recomendado)

Si pierdes la base de datos o las claves **no hay recuperación**. Esta edición no tiene PostgreSQL: un respaldo es simplemente un archivo con `data/tuwunel` (base de datos + multimedia) + `tuwunel.toml` + `.env`.

**Recomendado: activa los respaldos cifrados automáticos** (semanales, AES-256, con rotación automática, omitidos si el disco está casi lleno):

```bash
sudo tuwunel autobackup     # define carpeta / retención / frecuencia; imprime la clave: guárdala en un gestor de contraseñas
```

**O respalda ahora** (opción 5 del menú; puedes poner una frase de cifrado).

**Descarga a tu computadora** (ejecuta en tu propia máquina):

```bash
scp root@TU_IP_DEL_SERVIDOR:/opt/tuwunel/backups/*.enc ~/Desktop/
```

> 🔑 **Guarda la clave del respaldo.** Sin ella, un respaldo cifrado no se puede abrir jamás. La clave vive solo en el servidor: si el servidor desaparece y no la guardaste, los respaldos son inútiles.
> 💡 La carpeta local `backups/` muere con el servidor. Copia los archivos `.enc` a otro lado con regularidad, o apunta la carpeta de respaldos a un volumen externo montado / almacenamiento de objetos.

---

## ❓ Preguntas frecuentes

| Problema | Causa y solución |
|---|---|
| **Element X en el teléfono no conecta / "couldn't connect to this homeserver"** | **Primero, revisa la fecha y hora del teléfono** (Ajustes → Fecha y hora → "Automática"): un reloj mal ajustado falla la validación del certificado; es la causa más común (sobre todo en Android). Luego: prueba otra red, confirma que puedes abrir `https://tu-dominio/.well-known/matrix/client` en el navegador del teléfono, y actualiza Element X. |
| **Element X dice "necesita actualizarse para admitir el servicio de autenticación"** | Se refiere al registro. Confirma que el registro móvil está activo (`sudo tuwunel enable-elementx`) y que tuwunel está al día (`docker compose pull tuwunel`). O registra por web / `adduser` y que los miembros **inicien sesión con contraseña** en Element X. |
| **Los archivos grandes no suben** | Revisa el límite (`MAX_UPLOAD=10G sudo -E tuwunel config`); si usas Cloudflare, el host **`matrix` debe estar en nube gris** (el tope de 100 MB de la nube naranja mata los archivos grandes). |
| **El panel `admin.dominio` no abre / errores de login** | Suele faltar el registro DNS `admin` o el certificado aún no está listo: agrégalo y espera unos minutos. Para errores de login: `cd /opt/tuwunel && docker compose pull tuwunel && docker compose up -d`. |
| Olvidé la contraseña del admin | `cat /opt/tuwunel/CREDENTIALS.txt`; o `sudo tuwunel adduser` para crear un nuevo admin. |
| Cambiar la configuración (llamadas, registro, tamaño, admin) | Sin reinstalar: `sudo tuwunel config` — Enter mantiene los valores, datos/cuentas intactos. |
| Las llamadas conectan pero sin sonido/imagen | El 99% de las veces el puerto **7882/UDP** no está permitido: agrégalo en el firewall del proveedor. |
| El disco se llena | Opción 7 del menú "Limpiar disco"; para uso intensivo, provee un volumen grande o almacenamiento de objetos. |
| "No se puede descifrar" mensajes viejos en una sala cifrada | Normal: un dispositivo nuevo no tiene las claves históricas. Verifica la nueva sesión desde un dispositivo antiguo. |
| Desinstalar / reinstalar | `sudo tuwunel uninstall` (doble confirmación antes de borrar); reinstalar = desinstalar y volver a correr el comando de instalación. |

---

## 📦 Componentes del lado del servidor

Tras instalar, corren estos componentes, todos orquestados con Docker, de código abierto y auditables:

```
Caddy (HTTPS automático) + tuwunel (Rust, RocksDB integrado, sin PostgreSQL)
  + Element Web (tu propio cliente web, opcional)
  + Ketesa (panel de administración gráfico, opcional)
  + LiveKit + lk-jwt-service (llamadas, opcional)
```

Directorio de instalación `/opt/tuwunel`. Toda la lógica está en un único script, `matrix-tuwunel-installer.sh`, que puedes auditar tú mismo.

---

## 🆚 Edición tuwunel vs Synapse

El repositorio también incluye una edición Synapse (`matrix-installer.sh`). En resumen:

- **Edición tuwunel (este documento):** Rust, sin PostgreSQL, **más eficiente, mejor con archivos grandes**, 2 GB sirven a ~300 personas. Ideal para la mayoría de los equipos, sobre todo con uso intensivo de archivos grandes.
- **Edición Synapse:** Python + PostgreSQL, el ecosistema y las herramientas de administración más maduros, pero más pesada en RAM y más débil con archivos grandes.

**Para despliegues nuevos, se recomienda la edición tuwunel.**

---

## 📄 Licencia (nota: solo uso no comercial)

Este proyecto está licenciado bajo [PolyForm Noncommercial 1.0.0](LICENSE):

- ✅ **Gratis para uso personal / interno de equipo / investigación / organizaciones sin fines de lucro**: modifica y redistribuye libremente (conserva el aviso de copyright)
- ❌ **Todo uso comercial está prohibido** (venderlo, integrarlo en un producto comercial, ofrecerlo como servicio de pago, etc.)
- 🚫 **Están prohibidas la reventa en cualquier plataforma y los servicios pagos de "instalación/despliegue"**: este proyecto es gratuito; si ves a alguien vendiéndolo, es reventa no autorizada
- 💼 ¿Quieres una licencia comercial en regla? Abre un [Issue](../../issues) para contactar al autor.

Deja una Star ⭐ si te resulta útil.

---

<div align="center">
Hecho con ❤️ · para que todos puedan tener su propio servidor de comunicación privado
</div>
