<script setup>
import { ref, watch, onMounted, onUnmounted } from 'vue'
import MesaDados from '../components/MesaDados.vue'
import ModalGeneradorNpc from '../components/ModalGeneradorNpc.vue'

import FichaDatosPrincipales from '../components/personajes/FichaDatosPrincipales.vue'
import FichaCaracteristicas from '../components/personajes/FichaCaracteristicas.vue'
import FichaRasgosNotas from '../components/personajes/FichaRasgosNotas.vue'
import FichaAtaques from '../components/personajes/FichaAtaques.vue'
import FichaInventario from '../components/personajes/FichaInventario.vue'
import MercadoJugador from '../components/personajes/MercadoJugador.vue'

const mostrandoGeneradorInteligente = ref(false)

// Esta función recibe el NPC ya guardado en BD desde el modal
const atraparNpcGenerado = (npcData) => {
  mostrandoGeneradorInteligente.value = false
  // Acá podés agregarlo a tu lista local si querés, o tirar una alerta
  console.log("¡NPC creado y guardado con éxito!", npcData)
}

const route = useRoute()
const router = useRouter()
const supabase = useSupabaseClient()

const cargando = ref(true)
const esNuevo = ref(route.params.id === 'nuevo')
const modoEdicion = ref(esNuevo.value)
const listaPerfiles = ref([])
const mesaRef = ref(null)

const visionRevelada = ref(null)
let canalVision = null
let canalPjSync = null

const pj = ref({
  nombre_pj: '', raza: '', clase: '', nivel: 1, player_email: '', campaign_id: route.query.campana || null, tipo: route.query.tipo || 'pj',
  imagen_url: '', alineamiento: '', xp: 0, clase_armadura: 10, velocidad: 30, hp_max: 10, hp_actual: 10, salvaciones_exito: 0, salvaciones_fallo: 0,
  fuerza: 10, destreza: 10, constitucion: 10, inteligencia: 10, sabiduria: 10, carisma: 10,
  prof_fuerza_salv: false, prof_atletismo: false, prof_destreza_salv: false, prof_acrobacias: false, prof_juego_manos: false, prof_sigilo: false,
  prof_constitucion_salv: false, prof_inteligencia_salv: false, prof_arcano: false, prof_historia: false, prof_investigacion: false, prof_naturaleza: false, prof_religion: false,
  prof_sabiduria_salv: false, prof_medicina: false, prof_percepcion: false, prof_perspicacia: false, prof_supervivencia: false, prof_trato_animales: false,
  prof_carisma_salv: false, prof_engano: false, prof_intimidacion: false, prof_interpretacion: false, prof_persuasion: false,
  monedas_cobre: 0, monedas_plata: 0, monedas_oro: 0, monedas_platino: 0, inventario: [], ataques: [], notas_array: [], 
  edad: '', altura: '', peso: '', ojos: '', piel: '', pelo: '', vulnerabilidades: '', inmunidades: '', dificultad: ''
})

const todosLosEfectos = ref([])
const { data: efData } = await supabase.from('efectos').select('*').order('nombre')
if (efData) todosLosEfectos.value = efData

// Función puente para atrapar los dados de los hijos y mandarlos a la mesa
const procesarTiradaDado = ({titulo, cant, caras, bono, efecto}) => {
  mesaRef.value?.tirar(titulo, cant, caras, bono, efecto)
}

watch([() => pj.value.hp_actual, () => pj.value.hp_max], ([newActual, newMax]) => {
  if (newActual > newMax) pj.value.hp_actual = newMax
})

const cancelarEdicion = () => { if (esNuevo.value) { router.back() } else { cargarFicha(); if(pj.value.tipo === 'pj') modoEdicion.value = false } }

const cargarFicha = async () => {
  const { data: perfilesData } = await supabase.from('profiles').select('email, nombre')
  if (perfilesData) listaPerfiles.value = perfilesData

  if (!esNuevo.value) {
    const { data } = await supabase.from('characters').select('*').eq('id', route.params.id).single()
    if (data) {
      if (!data.inventario) data.inventario = []
      if (!data.ataques) data.ataques = []
      let notasParseadas = []; try { notasParseadas = data.notas ? JSON.parse(data.notas) : [] } catch { notasParseadas = [] }
      pj.value = { ...data, notas_array: notasParseadas }
      modoEdicion.value = false 
      
      if (pj.value.campaign_id) {
        const { data: campData } = await supabase.from('campaigns').select('mesa_estado').eq('id', pj.value.campaign_id).single()
        if (campData?.mesa_estado?.entidadVisible) visionRevelada.value = campData.mesa_estado.entidadVisible

        canalVision = supabase.channel('vision_jugador').on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'campaigns', filter: `id=eq.${pj.value.campaign_id}` }, (payload) => {
            if (payload.new.mesa_estado?.entidadVisible !== undefined) visionRevelada.value = payload.new.mesa_estado.entidadVisible
        }).subscribe()

        canalPjSync = supabase.channel('pj_sync_' + pj.value.id).on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'characters', filter: `id=eq.${pj.value.id}` }, (payload) => {
            if (payload.new.hp_actual !== undefined) pj.value.hp_actual = payload.new.hp_actual
            if (payload.new.efectos !== undefined) pj.value.efectos = payload.new.efectos
        }).subscribe()
      }
    }
  } else {
    pj.value.player_email = route.query.email || ''; pj.value.tipo = route.query.tipo || 'pj'; modoEdicion.value = true
  }
  cargando.value = false
}

// Modal Comunidad
const modalComunidadAbierto = ref(false)
const ataquesNuevos = ref([])
const mostrarEntidadComunidad = ref(false)
const compartirEntidad = ref(true)

const preGuardarFicha = () => {
  ataquesNuevos.value = pj.value.ataques.filter(a => a.es_nuevo && a.nombre !== '').map(a => ({ ...a, clase_destino: 'general' }))
  mostrarEntidadComunidad.value = esNuevo.value && (pj.value.tipo === 'npc' || pj.value.tipo === 'enemigo')
  if (ataquesNuevos.value.length > 0 || mostrarEntidadComunidad.value) modalComunidadAbierto.value = true
  else guardarFichaFinal()
}

const confirmarComunidad = async (compartirAtaques) => {
  modalComunidadAbierto.value = false; cargando.value = true
  if (compartirAtaques && ataquesNuevos.value.length > 0) {
    const inserts = ataquesNuevos.value.map(a => ({ nombre: a.nombre, bono: a.bono, cant_dados: a.cant_dados, tipo_dado: a.tipo_dado, bono_dano: a.bono_dano, rango: a.rango, descrip: a.desc, tipo_ataque: a.tipo_ataque, nivel: a.nivel, clase: a.clase_destino }))
    await supabase.from('ataques_comunidad').insert(inserts)
  }
  if (mostrarEntidadComunidad.value) pj.value.es_publico = compartirEntidad.value
  pj.value.ataques.forEach(a => delete a.es_nuevo)
  guardarFichaFinal()
}

const guardarFichaFinal = async () => {
  cargando.value = true
  try {
    const payload = { ...pj.value }
    payload.notas = JSON.stringify(payload.notas_array); delete payload.notas_array 
    let res;
    if (esNuevo.value) {
      res = await supabase.from('characters').insert([payload]).select()
      if (!res.error && res.data) { esNuevo.value = false; pj.value.id = res.data[0].id; router.replace(`/personajes/${res.data[0].id}`) }
    } else {
      res = await supabase.from('characters').update(payload).eq('id', payload.id)
    }
    if (res.error) throw res.error
    alert("¡Ficha guardada con éxito!")
    if(pj.value.tipo === 'pj') modoEdicion.value = false
  } catch (err) { alert("Error al forjar cambios.") } finally { cargando.value = false }
}

onMounted(() => { cargarFicha() })
onUnmounted(() => { if (canalVision) supabase.removeChannel(canalVision); if (canalPjSync) supabase.removeChannel(canalPjSync) })
</script>

<template>
  <div v-if="pj.efectos && pj.efectos.length > 0" class="barra-estados">
    <div v-for="(efecto, idx) in pj.efectos" :key="idx" class="badge-estado">{{ efecto.icono }} {{ efecto.nombre }}</div>
  </div>

  <div class="pantalla-ficha">
    <div class="filtro-oscuro"></div>

    <div v-if="visionRevelada" class="vision-dm-overlay">
      <div class="caja-revelacion">
        <h2 class="titulo-revelado">{{ visionRevelada.nombre }}</h2>
        <img v-if="visionRevelada.imagen" :src="visionRevelada.imagen" class="img-revelada" />
        <div v-else class="fallback-revelado">💀</div>
      </div>
    </div>

    <MesaDados v-if="!cargando && pj.campaign_id" ref="mesaRef" :jugador="pj.nombre_pj" :campana-id="pj.campaign_id" />

    <div v-if="cargando" class="cargando">Abriendo grimorio...</div>
    
    <div v-else class="contenedor-principal">
      <div class="controles-superiores">
        <button @click="router.push('../dashboard')" class="btn-ghost">← Regresar</button>
        <div class="acciones-derecha">
          <button v-if="modoEdicion && pj.tipo === 'pj'" @click="cancelarEdicion" class="btn-rojo">✖ Cancelar</button>
          <button v-if="!modoEdicion" @click="modoEdicion = true" class="btn-ghost">✏️ Editar Ficha</button>
          <button @click="mostrandoGeneradorInteligente = true" class="btn-accion-dm dorado">✨ Creación Rápida</button>
          <button v-if="modoEdicion" @click="preGuardarFicha" class="btn-dorado">💾 Sellar Cambios</button>
        </div>
      </div>

      <div class="layout-maestro">
        <FichaDatosPrincipales :pj="pj" :modoEdicion="modoEdicion" :listaPerfiles="listaPerfiles" />
        <FichaCaracteristicas :pj="pj" :modoEdicion="modoEdicion" @lanzar-dado="procesarTiradaDado" />

        <div class="grilla-detalles">
          <FichaRasgosNotas :pj="pj" :modoEdicion="modoEdicion" />
          <FichaAtaques :pj="pj" :modoEdicion="modoEdicion" :todosLosEfectos="todosLosEfectos" @lanzar-dado="procesarTiradaDado" />
          <FichaInventario :pj="pj" :modoEdicion="modoEdicion" />
        </div>
      </div>
    </div>

    <MercadoJugador v-if="!cargando && pj.id" :pj="pj" :es-nuevo="esNuevo" />
  </div>

  <div v-if="modalComunidadAbierto" class="modal-overlay">
    <div class="modal-taberna">
      <h2>🍻 Aportes a La Taberna del DM</h2>
      <p class="taberna-desc">¡Tu conocimiento puede ayudar a otros aventureros y DMs del multiverso!</p>
      <div v-if="mostrarEntidadComunidad" class="seccion-comunidad-box bestiario-box">
        <h3>📖 Bestiario Público</h3>
        <label class="check-bestiario"><input type="checkbox" v-model="compartirEntidad" /> Hacer público este {{ pj.tipo === 'npc' ? 'NPC' : 'Enemigo' }}</label>
      </div>
      <div v-if="ataquesNuevos.length > 0" class="seccion-comunidad-box">
        <h3>⚔️ Grimorio de Ataques y Magia</h3>
        <div class="lista-nuevos-ataques">
          <div v-for="(nuevo, index) in ataquesNuevos" :key="index" class="item-nuevo-atk">
            <div class="atk-info-comunidad"><span>{{ nuevo.nombre }}</span></div>
            <select v-model="nuevo.clase_destino" class="input-base select-dark"><option value="general">Clase General</option><option value="mago">Mago</option></select>
          </div>
        </div>
      </div>
      <div class="modal-botones-taberna">
        <button class="btn-no-compartir" @click="confirmarComunidad(false)">Guardar privado</button>
        <button class="btn-si-compartir" @click="confirmarComunidad(true)">Aceptar y Forjar</button>
      </div>
    </div>
  </div>

  <ModalGeneradorNpc 
  v-if="mostrandoGeneradorInteligente" 
  @cerrar="mostrandoGeneradorInteligente = false"
  @guardar-npc="atraparNpcGenerado"
/>
</template>