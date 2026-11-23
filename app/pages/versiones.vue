<script setup>
useHead({ title: 'Historial de versiones' })
const usuario = useSupabaseUser()
const versiones = [
  {
    numero: '0.5.0', fecha: '2026-11-22', fechaVisible: '22 de noviembre de 2026',
    titulo: 'Fundación de asentamientos',
    cambios: [
      'Fundá una aldea, pueblo, ciudad o metrópolis con locales editables y mercadería inicial según el catálogo.',
      'Cada campaña tiene su propio atlas. Las tiradas secretas y los pergaminos quedan reservados al director.',
      'Un resultado negativo ya no invierte el daño y la curación. Las salvaciones de muerte se pueden desmarcar.',
      'El stock conserva las referencias anteriores al editar cantidades y los aliados pueden autorizar un pago desde su ficha.'
    ]
  },
  {
    numero: '0.4.0', fecha: '2026-11-20', fechaVisible: '20 de noviembre de 2026',
    titulo: 'Dados tallados',
    cambios: [
      'Los dados ruedan y se asientan sobre un tapete compartido por la mesa del DM y las fichas.',
      'El d100 muestra decenas y unidades. Los resultados naturales de 1 y 20 se destacan en el d20.',
      'Repetí la última tirada con los mismos dados y bono, incluso desde una prueba de característica.',
      'El orden de iniciativa indica quién juega ahora y quién sigue.'
    ]
  },
  {
    numero: '0.3.0', fecha: '2026-11-20', fechaVisible: '20 de noviembre de 2026',
    titulo: 'Dados y aliados',
    cambios: [
      'La mesa separa el resultado del tapete y permite quitar un solo dado de la selección.',
      'Cada grupo de la campaña tiene un acceso para crear su tipo de ficha.',
      'Los pedidos de ayuda para pagar siguen disponibles al volver a abrir la ficha del aliado.'
    ]
  },
  {
    numero: '0.2.0', fecha: '2026-11-20', fechaVisible: '20 de noviembre de 2026',
    titulo: 'La taberna y sus mercados',
    cambios: [
      'La campaña muestra su portada y reúne los accesos a la mesa, el atlas y el grimorio.',
      'Buscá ciudades por nombre y pergaminos por título.',
      'La caja muestra el total negociado en cobre. La forja crea el objeto y lo suma al stock en una sola operación.'
    ]
  },
  {
    numero: '0.1.0', fecha: '2026-11-20', fechaVisible: '20 de noviembre de 2026',
    titulo: 'Cuaderno del director',
    cambios: [
      'Leé y editá pergaminos desde la mesa del DM o en pantalla completa.',
      'El título y el texto se guardan automáticamente. Podés asociar imágenes a palabras del pergamino.',
      'La mesa y las fichas se adaptan a pantallas chicas.',
      'El tablero carga solo los datos necesarios para mostrar tus campañas y personajes.'
    ]
  }
]
</script>

<template>
  <main class="historial">
    <div class="columna">
      <NuxtLink :to="usuario ? '/dashboard' : '/'">← Volver a la taberna</NuxtLink>
      <h1>Historial de versiones</h1>
      <article v-for="version in versiones" :key="version.numero">
        <header><strong>v{{ version.numero }}</strong><time :datetime="version.fecha">{{ version.fechaVisible }}</time></header>
        <h2>{{ version.titulo }}</h2>
        <ul><li v-for="cambio in version.cambios" :key="cambio">{{ cambio }}</li></ul>
      </article>
    </div>
  </main>
</template>

<style scoped>
.historial { min-height: 100vh; background: #0a0a0c; color: #e4e4e7; padding: clamp(1.25rem, 5vw, 4rem); font: 1rem/1.6 Inter, sans-serif; }
.columna { max-width: 46rem; margin-inline: auto; }
.historial a { color: #93c5fd; text-decoration: underline; }
h1, h2 { font-family: Cinzel, Georgia, serif; color: #fde68a; }
h1 { margin: 2rem 0 1rem; font-size: clamp(1.85rem, 6vw, 3rem); }
h2 { margin: .75rem 0; font-size: 1.5rem; }
article { padding: clamp(1rem, 4vw, 2rem); border: 1px solid #334155; border-radius: .75rem; background: #111115; }
article + article { margin-top: 1rem; }
header { display: flex; flex-wrap: wrap; align-items: baseline; gap: .5rem 1rem; }
strong { color: #facc15; }
time { font-size: .88rem; color: #a1a1aa; }
ul { padding-left: 1.2rem; list-style: disc; }
li + li { margin-top: .45rem; }
</style>
