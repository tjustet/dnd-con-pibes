<script setup>
import { computed } from 'vue'

const props = defineProps({
  pj: { type: Object, required: true },
  modoEdicion: { type: Boolean, default: false },
  listaPerfiles: { type: Array, default: () => [] }
})

const hpPorcentaje = computed(() => {
  if (props.pj.hp_max <= 0) return 0
  return Math.max(0, Math.min(100, (props.pj.hp_actual / props.pj.hp_max) * 100))
})

const reiniciarMuerte = () => { props.pj.salvaciones_exito = 0; props.pj.salvaciones_fallo = 0 }
</script>

<template>
  <div class="panel-identidad">
    <div class="avatar-box">
      <img v-if="pj.imagen_url" :src="pj.imagen_url" class="avatar-img" />
      <div v-else class="avatar-placeholder">🛡️</div>
      <input v-if="modoEdicion" v-model="pj.imagen_url" placeholder="URL imagen" class="input-fino mt-1" />
    </div>

    <div class="datos-identidad">
      <div class="nombre-box">
        <input v-if="modoEdicion" v-model="pj.nombre_pj" placeholder="Nombre" class="input-titulo" />
        <h1 v-else class="texto-titulo">{{ pj.nombre_pj || 'Sin nombre' }}</h1>
      </div>
      
      <div class="tags-basicos">
        <div class="tag" v-if="pj.tipo !== 'pj'">
          <label>TIPO DE ENTIDAD</label>
          <select v-model="pj.tipo" class="input-base select-dark" :disabled="!modoEdicion">
            <option value="npc">NPC</option><option value="enemigo">Enemigo</option>
          </select>
        </div>
        <div class="tag"><label>CLASE</label><input v-if="modoEdicion" v-model="pj.clase" class="input-base" /><span v-else>{{ pj.clase || '-' }}</span></div>
        <div class="tag"><label>NIVEL</label><input v-if="modoEdicion" type="number" v-model="pj.nivel" class="input-base" /><span v-else>{{ pj.nivel || 1 }}</span></div>
        <div class="tag"><label>RAZA</label><input v-if="modoEdicion" v-model="pj.raza" class="input-base" /><span v-else>{{ pj.raza || '-' }}</span></div>
        <div class="tag"><label>ALINEAMIENTO</label><input v-if="modoEdicion" v-model="pj.alineamiento" class="input-base" /><span v-else>{{ pj.alineamiento || '-' }}</span></div>
        <div class="tag"><label>{{ pj.tipo === 'pj' ? 'XP' : 'XP (OTORGA)' }}</label><input v-if="modoEdicion" type="number" v-model="pj.xp" class="input-base" /><span v-else>{{ pj.xp || 0 }}</span></div>
        <div v-if="modoEdicion && pj.tipo === 'pj'" class="tag selector-email-container">
          <label>VINCULAR JUGADOR (EMAIL)</label>
          <select v-model="pj.player_email" class="select-dark">
            <option value="">-- Dejar sin asignar --</option>
            <option v-for="prof in listaPerfiles" :key="prof.email" :value="prof.email">{{ prof.nombre }} ({{ prof.email }})</option>
          </select>
        </div>
      </div>
    </div>

    <div class="bloque-vitalidad">
      <div class="defensas">
        <div class="escudo-ca">
          <input v-if="modoEdicion" type="number" v-model="pj.clase_armadura" class="input-ca" />
          <span v-else>{{ pj.clase_armadura }}</span>
          <span class="lbl-escudo">CA</span>
        </div>
        <div class="box-chico">
          <label>VELOCIDAD</label>
          <div class="val-chico"><input v-if="modoEdicion" type="number" v-model="pj.velocidad" class="input-inline" /><span v-else>{{ pj.velocidad }}</span> ft</div>
        </div>
      </div>

      <div class="caja-hp">
        <div class="hp-header">
          <span class="lbl-dorado">VIDA</span>
          <span class="hp-max-text">MÁX: <input v-if="modoEdicion" type="number" v-model="pj.hp_max" class="input-inline" /><span v-else>{{ pj.hp_max }}</span></span>
        </div>
        <div class="hp-centro">
          <input v-if="modoEdicion" type="number" v-model="pj.hp_actual" class="input-hp-gigante" />
          <span v-else class="texto-hp-gigante">{{ pj.hp_actual }}</span>
        </div>
        <div class="barra-hp-fondo"><div class="barra-hp-relleno" :style="`width: ${hpPorcentaje}%`"></div></div>
      </div>

      <div v-if="pj.tipo === 'pj'" class="caja-muerte">
        <div class="header-muerte">
          <label>SALVACIONES DE MUERTE</label>
          <button v-if="modoEdicion" @click="reiniciarMuerte" class="btn-reinicio">↻</button>
        </div>
        <div class="death-row">
          <span>ÉXITOS</span>
          <input type="checkbox" :checked="pj.salvaciones_exito >= 1" @change="pj.salvaciones_exito = $event.target.checked ? 1 : 0" :disabled="!modoEdicion">
          <input type="checkbox" :checked="pj.salvaciones_exito >= 2" @change="pj.salvaciones_exito = $event.target.checked ? 2 : pj.salvaciones_exito" :disabled="!modoEdicion">
          <input type="checkbox" :checked="pj.salvaciones_exito >= 3" @change="pj.salvaciones_exito = $event.target.checked ? 3 : pj.salvaciones_exito" :disabled="!modoEdicion">
        </div>
        <div class="death-row">
          <span>FALLOS</span>
          <input type="checkbox" :checked="pj.salvaciones_fallo >= 1" @change="pj.salvaciones_fallo = $event.target.checked ? 1 : 0" :disabled="!modoEdicion">
          <input type="checkbox" :checked="pj.salvaciones_fallo >= 2" @change="pj.salvaciones_fallo = $event.target.checked ? 2 : pj.salvaciones_fallo" :disabled="!modoEdicion">
          <input type="checkbox" :checked="pj.salvaciones_fallo >= 3" @change="pj.salvaciones_fallo = $event.target.checked ? 3 : pj.salvaciones_fallo" :disabled="!modoEdicion">
        </div>
      </div>
    </div>
  </div>
</template>