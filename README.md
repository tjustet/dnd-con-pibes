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
