<script setup>
import EditorNotas from '../../../components/NotasDM.vue'

definePageMeta({
  path: '/campanas/:id/notas',
  alias: ['/campanas/:id/NotasDM'],
  middleware: ['director', (to) => {
    // El botón existente de la campaña y los marcadores antiguos usan /NotasDM.
    if (to.path.replace(/\/$/, '').toLowerCase().endsWith('/notasdm')) {
      return navigateTo({
        path: `/campanas/${to.params.id}/notas`,
        query: to.query,
        hash: to.hash
      }, { replace: true })
    }
  }]
})

const route = useRoute()
useHead({
  title: 'Notas del DM',
  htmlAttrs: { class: 'pagina-notas-dm' },
  bodyAttrs: { class: 'pagina-notas-dm' }
})
</script>

<template>
  <EditorNotas :campaign-id="route.params.id" :pantalla-completa="true" />
</template>

<style scoped>
:global(html.pagina-notas-dm),
:global(body.pagina-notas-dm) {
  margin: 0;
  overflow: hidden;
}
</style>
