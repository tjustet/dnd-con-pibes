<script setup>
const props = defineProps({
  ordenIniciativa: Array,
  turnoActual: Number
})
const emit = defineEmits(['siguiente-turno'])
const lista = ref(null)
const proximo = computed(() => props.ordenIniciativa.length > 1
  ? props.ordenIniciativa[(props.turnoActual + 1) % props.ordenIniciativa.length] : null)
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
      <p v-if="proximo" class="proximo">Le sigue {{ proximo.nombre }}</p>
      <button @click="emit('siguiente-turno')" class="btn-siguiente-turno">Siguiente turno</button>
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
.proximo { margin: 0; font-size: .82rem; color: #c9bdcb; overflow-wrap: anywhere; }
.controles-iniciativa { max-width: min(15rem,100%); }
.combatiente-card.es-su-turno { transform: translateY(-2px); box-shadow: 0 3px 12px #0007; border-color: #d7ab62; }
.combatiente-card.es-su-turno::after { content: ''; position: absolute; inset: auto 15% -2px; height: 3px; border-radius: 2px; background: #ffe1a1; animation: marcar-turno .32s ease-out; }
@keyframes marcar-turno { from { transform: scaleX(.15); } to { transform: scaleX(1); } }
@media (prefers-reduced-motion: no-preference) { .tracker-scroll { scroll-behavior: smooth; } }
</style>
