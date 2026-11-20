<script setup>
const props = defineProps({
  ordenIniciativa: Array,
  turnoActual: Number
})
const emit = defineEmits(['siguiente-turno'])
const lista = ref(null)
watch(() => props.turnoActual, () => {
  const contenedor = lista.value
  const tarjeta = contenedor?.children[props.turnoActual]
  if (!tarjeta) return
  const zona = contenedor.getBoundingClientRect()
  const actual = tarjeta.getBoundingClientRect()
  if (actual.left < zona.left) contenedor.scrollLeft += actual.left - zona.left - 8
  else if (actual.right > zona.right) contenedor.scrollLeft += actual.right - zona.right + 8
}, { flush: 'post' })
</script>

<template>
  <div class="barra-iniciativa">
    <div class="controles-iniciativa">
      <p class="turno-activo" aria-live="polite">Turno de <strong>{{ ordenIniciativa[turnoActual]?.nombre }}</strong></p>
      <button @click="emit('siguiente-turno')" class="btn-siguiente-turno">Siguiente Turno ➔</button>
    </div>
    <div ref="lista" class="tracker-scroll">
      <div v-for="(combatiente, idx) in ordenIniciativa" :key="combatiente.unique_id" class="combatiente-card" :aria-current="idx === turnoActual ? 'step' : undefined" :class="{'es-su-turno': idx === turnoActual}">
        <div class="c-badge">{{ combatiente.total }}</div>
        <img v-if="combatiente.imagen" :src="combatiente.imagen" class="c-avatar" alt="" />
        <div v-else class="c-fallback">👤</div>
        <div class="c-info"><span class="c-nom">{{ combatiente.nombre }}</span></div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.controles-iniciativa { display: grid; gap: .45rem; }
.turno-activo { margin: 0; color: #cbd5e1; font-size: .9rem; }
.turno-activo strong { color: #fde68a; }
</style>
