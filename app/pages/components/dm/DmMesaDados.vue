<script setup>
const props = defineProps({
  historialCompartido: Array,
  todasLasEntidadesActivas: Array,
  dmDadosEnMesa: Array,
  dmTirando: Boolean,
  dmResultadoFinal: Number,
  dmPool: Array
})

// Enlace bidireccional mágico para el input numérico
const dmBono = defineModel('dmBono')

const emit = defineEmits([
  'limpiar-historial', 'aplicar-dano', 'curar-dano', 'aplicar-efecto',
  'agregar-dado', 'limpiar-pool', 'tirar-pool'
])
</script>

<template>
  <div class="centro-dados-dm">
    <div class="mesa-central-fisica">
      <div class="mesa-mitad-izq">
        <div class="header-historial-dm">
          <h4 class="tit-seccion-mesa" style="margin: 0; border: none;">Registro Global</h4>
          <button @click="emit('limpiar-historial')" class="btn-limpiar-historial" title="Borrar historial">🧹</button>
        </div>
        <div class="historial-dm-scroll">
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
      </div>

      <div class="mesa-mitad-der">
        <div class="tapete-caida-wrap">
          <div class="tapete-caida">
            <div v-for="(d, idx) in dmDadosEnMesa" :key="idx" class="dado-dm-3d" :class="{'dado-girando': dmTirando, ['dado-d'+d.caras]: true}">{{ d.valor }}</div>
          </div>
          <div v-if="!dmTirando && dmResultadoFinal > 0" class="resultado-gigante-dm">{{ dmResultadoFinal }}</div>
        </div>
        <div class="controles-mesa">
          <div class="fila-botones-dados">
            <button @click="emit('agregar-dado', 4)">d4</button>
            <button @click="emit('agregar-dado', 6)">d6</button>
            <button @click="emit('agregar-dado', 8)">d8</button>
            <button @click="emit('agregar-dado', 10)">d10</button>
            <button @click="emit('agregar-dado', 12)">d12</button>
            <button @click="emit('agregar-dado', 20)" class="d20-btn">d20</button>
            <button @click="emit('agregar-dado', 100)">d100</button>
          </div>
          <div class="fila-acciones-mesa">
            <div class="pool-viewer">
              <span v-if="dmPool.length === 0" class="pool-vacio">Seleccioná dados...</span>
              <span v-for="(p, i) in dmPool" :key="i" class="pool-badge">d{{ p }}</span>
            </div>
            <div class="inputs-mesa-final">
              <input type="number" v-model="dmBono" placeholder="Bono" class="input-bono-dm" />
              <button class="btn-clear-dm" @click="emit('limpiar-pool')">✖</button>
              <button class="btn-roll-dm" @click="emit('tirar-pool', null)">ROLL</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>