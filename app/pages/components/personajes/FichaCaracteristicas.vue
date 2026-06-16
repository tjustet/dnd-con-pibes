<script setup>
const props = defineProps({
  pj: { type: Object, required: true },
  modoEdicion: { type: Boolean, default: false }
})
const emit = defineEmits(['lanzarDado'])

const caracteristicas = [
  { id: 'fuerza', nombre: 'FUERZA', habilidades: [{ id: 'prof_fuerza_salv', nombre: 'Salvación' }, { id: 'prof_atletismo', nombre: 'Atletismo' }] },
  { id: 'destreza', nombre: 'DESTREZA', habilidades: [{ id: 'prof_destreza_salv', nombre: 'Salvación' }, { id: 'prof_acrobacias', nombre: 'Acrobacias' }, { id: 'prof_juego_manos', nombre: 'Juegos de Manos' }, { id: 'prof_sigilo', nombre: 'Sigilo' }] },
  { id: 'constitucion', nombre: 'CONSTITUCIÓN', habilidades: [{ id: 'prof_constitucion_salv', nombre: 'Salvación' }] },
  { id: 'inteligencia', nombre: 'INTELIGENCIA', habilidades: [{ id: 'prof_inteligencia_salv', nombre: 'Salvación' }, { id: 'prof_arcano', nombre: 'C. Arcano' }, { id: 'prof_historia', nombre: 'Historia' }, { id: 'prof_investigacion', nombre: 'Investigación' }, { id: 'prof_naturaleza', nombre: 'Naturaleza' }, { id: 'prof_religion', nombre: 'Religión' }] },
  { id: 'sabiduria', nombre: 'SABIDURÍA', habilidades: [{ id: 'prof_sabiduria_salv', nombre: 'Salvación' }, { id: 'prof_medicina', nombre: 'Medicina' }, { id: 'prof_percepcion', nombre: 'Percepción' }, { id: 'prof_perspicacia', nombre: 'Perspicacia' }, { id: 'prof_supervivencia', nombre: 'Supervivencia' }, { id: 'prof_trato_animales', nombre: 'T. Animales' }] },
  { id: 'carisma', nombre: 'CARISMA', habilidades: [{ id: 'prof_carisma_salv', nombre: 'Salvación' }, { id: 'prof_engano', nombre: 'Engaño' }, { id: 'prof_intimidacion', nombre: 'Intimidación' }, { id: 'prof_interpretacion', nombre: 'Interpretación' }, { id: 'prof_persuasion', nombre: 'Persuasión' }] }
]

const calcMod = (valor) => Math.floor((valor - 10) / 2)
const calcModStr = (valor) => { const m = calcMod(valor); return m >= 0 ? `+${m}` : m }
const calcHabilidadNum = (statBase, isProf) => calcMod(props.pj[statBase]) + (isProf ? 3 : 0)
const calcHabilidadStr = (statBase, isProf) => { const total = calcHabilidadNum(statBase, isProf); return total >= 0 ? `+${total}` : total }

const tirarStat = (nombre, statBase) => emit('lanzarDado', { titulo: `Prueba de ${nombre}`, cant: 1, caras: 20, bono: calcMod(props.pj[statBase]) })
const tirarHab = (nombre, statBase, isProf) => emit('lanzarDado', { titulo: nombre, cant: 1, caras: 20, bono: calcHabilidadNum(statBase, isProf) })
</script>

<template>
  <div class="grilla-estadisticas">
    <div v-for="car in caracteristicas" :key="car.id" class="caja-stat">
      <div class="stat-top"><span class="nombre-stat">{{ car.nombre }}</span></div>
      <div class="stat-mid" :class="{'interactivo': !modoEdicion && pj.tipo === 'pj'}" @click="!modoEdicion && pj.tipo === 'pj' && tirarStat(car.nombre, car.id)">
        <div class="modificador-gigante">{{ calcModStr(pj[car.id]) }}</div>
        <div class="puntuacion-base">
          <input v-if="modoEdicion" type="number" v-model="pj[car.id]" class="input-stat-chico" @click.stop />
          <span v-else>{{ pj[car.id] }}</span>
        </div>
      </div>
      <div class="stat-skills">
        <div v-for="hab in car.habilidades" :key="hab.id" class="item-habilidad" :class="{'interactivo': !modoEdicion && pj.tipo === 'pj'}" @click="!modoEdicion && pj.tipo === 'pj' && tirarHab(hab.nombre, car.id, pj[hab.id])">
          <input v-if="modoEdicion" type="checkbox" v-model="pj[hab.id]" class="check-hab" @click.stop />
          <span v-else class="punto-competencia" :class="{ activo: pj[hab.id] }">●</span>
          <span class="valor-hab">{{ calcHabilidadStr(car.id, pj[hab.id]) }}</span>
          <span class="nombre-hab" :class="{ 'texto-competente': pj[hab.id] && !modoEdicion }">{{ hab.nombre }}</span>
        </div>
      </div>
    </div>
  </div>
</template>