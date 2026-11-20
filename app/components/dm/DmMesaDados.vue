<script setup>
import LanzadorDados from '../dados/LanzadorDados.vue'
defineProps({
  historialCompartido: Array,
  todasLasEntidadesActivas: Array,
  tirada: Object,
  dmTirando: Boolean,
  dmPool: Array
})

const dmBono = defineModel('dmBono')

const emit = defineEmits([
  'limpiar-historial', 'aplicar-dano', 'curar-dano', 'aplicar-efecto',
  'agregar-dado', 'quitar-dado', 'limpiar-pool', 'tirar-pool', 'repetir'
])
</script>

<template>
  <div class="centro-dados-dm">
    <div class="estacion">
      <LanzadorDados titulo="Mesa de dados" :pool="dmPool" :tirada="tirada" :tirando="dmTirando" v-model:bono="dmBono"
        @agregar="emit('agregar-dado',$event)" @quitar="emit('quitar-dado',$event)"
        @limpiar="emit('limpiar-pool')" @tirar="emit('tirar-pool')" @repetir="emit('repetir')" />
      <aside class="registro">
        <div class="cabecera-registro">
          <h3>Historial de tiradas</h3>
          <button type="button" :disabled="!historialCompartido.length" @click="emit('limpiar-historial')">Borrar</button>
        </div>
        <div class="historial-dm-scroll">
          <p v-if="!historialCompartido.length">Todavía no hay tiradas.</p>
          <div v-for="h in historialCompartido" :key="h.id" class="hist-item-dm" :class="{'oculto-bg': h.oculto}">
            <div class="h-header">
              <span class="h-tirador" :class="{'t-dorado': h.tirador === 'DM'}">{{ h.tirador }}</span>
              <span v-if="h.oculto" class="ojo-oculto">👁️‍🗨️</span>
            </div>
            <div class="h-tit">{{ h.titulo }}</div>
            <div class="h-datos">{{ h.dadosStr }}</div>
            <div class="h-body-row">
              <div class="h-bono">Bono: {{ h.bono >= 0 ? '+' : '' }}{{ h.bono }}</div>
              <div class="h-total">{{ h.total }}</div>
            </div>
            
            <button class="btn-toggle-dano" @click="h.mostrarAsignador = !h.mostrarAsignador">🎯 Asignar...</button>
            <div v-if="h.mostrarAsignador" class="asignador-box">
              <select v-model="h.targetAsignado" class="select-target">
                <option value="">Blanco...</option>
                <option v-for="ent in todasLasEntidadesActivas" :key="ent.instance_id || ent.id" :value="ent.instance_id || ent.id">{{ ent.nombre_pj }}</option>
              </select>
              <div class="asignador-acciones" v-if="h.targetAsignado">
                <button class="btn-asig dmg" @click="emit('aplicar-dano', h)">Daño</button>
                <button class="btn-asig heal" @click="emit('curar-dano', h)">Cura</button>
                <button v-if="h.efecto_vinculado" class="btn-asig veneno" @click="emit('aplicar-efecto', h)" :title="h.efecto_vinculado.descripcion">{{ h.efecto_vinculado.icono }} Estado</button>
              </div>
            </div>
          </div>
        </div>
      </aside>
    </div>
  </div>
</template>

<style scoped>
.centro-dados-dm { display: block; height: auto; min-width: 0; container-type: inline-size; }
.estacion { display: grid; grid-template-columns: minmax(0, 1fr) minmax(12rem, 31%); background: #101113; border: 1px solid #4e4434; border-radius: 12px; overflow: hidden; color: #eee9e0; }
.cabecera-registro { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: .45rem; }
h3 { font: 600 .96rem/1.35 Cinzel,Georgia,serif; color: #e4d4b8; margin: 0; }
.cabecera-registro button { border: 1px solid #51454b; border-radius: 5px; padding: .35rem .55rem; font-size: .82rem; color: #dfc79c; }
.registro { min-width: 0; padding: .85rem; }
.historial-dm-scroll > p { color: #c0b8c6; font-size: .87rem; }
.registro { border-left: 1px solid #373530; display: grid; grid-template-rows: auto minmax(0,1fr); gap: .7rem; background: #101014; }
.historial-dm-scroll { height: auto; max-height: 24rem; min-height: 0; }
@container (max-width: 39rem) {
  .estacion { grid-template-columns: minmax(0,1fr); }
  .registro { border-left: 0; border-top: 1px solid #373530; }
  .historial-dm-scroll { max-height: 11rem; }
}
</style>
