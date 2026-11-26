# Git - Guía rápida

## Descargar los últimos cambios

```bash
git pull origin main
```

## Subir cambios

1. Agregar archivos modificados:

```bash
git add .
```

2. Crear un commit:

```bash
git commit -m "Descripción de los cambios"
```

Ejemplo:

```bash
git commit -m "Se agregó pantalla de login"
```

3. Subir los cambios:

```bash
git push origin main
```

## Flujo de trabajo completo

```bash
git pull origin main
git add .
git commit -m "Descripción de los cambios"
git push origin main
```

## Comandos útiles

Ver estado del repositorio:

```bash
git status
```

Ver historial de commits:

```bash
git log --oneline
```

Ver rama actual:

```bash
git branch
```



# Nuxt Minimal Starter

Look at the [Nuxt documentation](https://nuxt.com/docs/getting-started/introduction) to learn more.

## Setup

Make sure to install dependencies:

```bash
# npm
npm install

# pnpm
pnpm install

# yarn
yarn install

# bun
bun install
```

## Development Server

Start the development server on `http://localhost:3000`:

```bash
# npm
npm run dev

# pnpm
pnpm dev

# yarn
yarn dev

# bun
bun run dev
```

## Production

Build the application for production:

```bash
# npm
npm run build

# pnpm
pnpm build

# yarn
yarn build

# bun
bun run build
```

Locally preview production build:

```bash
# npm
npm run preview

# pnpm
pnpm preview

# yarn
yarn preview

# bun
bun run preview
```

Check out the [deployment documentation](https://nuxt.com/docs/getting-started/deployment) for more information.

## Ejecutar la aplicación revisada

Esta copia conserva el lockfile del proyecto (Nuxt 4.4.8). Usá Node 22.12 o superior de la rama 22, o Node 24.11 o superior de la rama 24.

1. Extraé el proyecto en una carpeta nueva y copiá tu archivo `.env` de la app original a la raíz. Los componentes y el middleware ahora viven en `app/components` y `app/middleware`.
2. En una instalación nueva con el esquema base de D&D, aplicá las migraciones de `supabase/migrations` en orden. Habilitan la búsqueda de notas, la venta y la forja de objetos. Usa el esquema público existente de personajes, campañas, perfiles, tiendas y catálogos. Conserva las equivalencias de monedas de tu aplicación.
3. Desde la raíz ejecutá los comandos siguientes.

```bash
npm ci
npm run dev
```

Las pruebas de lógica se ejecutan con `node --test tests/*.test.js`. Para generar el servidor de producción usá `npm run build`.

La comprobación de una partida completa requiere dos sesiones de la misma campaña, una de DM y otra de jugador. La publicación Realtime incluye `campaigns`, `characters` y `campana_publicada`. Esta última comparte con los jugadores el nombre de la campaña, la visión y las tiradas públicas. Para el recorrido del comercio, proyectá un catálogo con stock, agregá un objeto desde el personaje y aprobá el pedido desde la mesa. El personaje debe recibir la cantidad pedida y la tienda debe descontar esa misma cantidad. Los catálogos proyectados por una versión anterior se actualizan al volver a proyectarlos.
