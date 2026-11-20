<script setup>
const props = defineProps({
  ordenIniciativa: Array,
  turnoActual: Number
})
const emit = defineEmits(['siguiente-turno'])
</script>

<template>
  <div class="barra-iniciativa">
    <div class="controles-iniciativa">
      <button @click="emit('siguiente-turno')" class="btn-siguiente-turno">Siguiente Turno ➔</button>
    </div>
    <div class="tracker-scroll">
      <div v-for="(combatiente, idx) in ordenIniciativa" :key="combatiente.unique_id" class="combatiente-card" :class="{'es-su-turno': idx === turnoActual}">
        <div class="c-badge">{{ combatiente.total }}</div>
        <img v-if="combatiente.imagen" :src="combatiente.imagen" class="c-avatar" />
        <div v-else class="c-fallback">👤</div>
        <div class="c-info"><span class="c-nom">{{ combatiente.nombre }}</span></div>
      </div>
    </div>
  </div>
</template>