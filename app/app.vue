<script setup>
const { aviso } = useAvisos()
let plazo
watch(aviso, mensaje => {
  clearTimeout(plazo)
  if (mensaje) plazo = setTimeout(() => { aviso.value = null }, mensaje.error ? 9000 : 4000)
})
onBeforeUnmount(() => clearTimeout(plazo))
useHead({ htmlAttrs: { lang: 'es-AR' }, titleTemplate: titulo => titulo ? `${titulo} · La Taberna del DM` : 'La Taberna del DM' })
</script>

<template>
  <div>
    <NuxtPage :page-key="ruta => ruta.path" />
    <div v-if="aviso" class="aviso-partida" :class="{ error: aviso.error }" role="status">
      {{ aviso.texto }}
      <button type="button" aria-label="Cerrar aviso" @click="aviso = null">×</button>
    </div>
  </div>
</template>

<style>
@import '../assets/css/ficha.css';
@import '../assets/css/dm.css';
@import '../assets/css/partida.css';
</style>
