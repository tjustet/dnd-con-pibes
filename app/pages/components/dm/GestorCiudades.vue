<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import ModalGeneradorNpc from '../ModalGeneradorNpc.vue'

const supabase = useSupabaseClient()
const route = useRoute()

// --- CONFIGURACIONES ---
const tamanos = [
  { id: 'aldea', nombre: 'Aldea (Pequeña)', maxTiendas: 4 },
  { id: 'pueblo', nombre: 'Pueblo (Mediano)', maxTiendas: 10 },
  { id: 'ciudad', nombre: 'Ciudad (Grande)', maxTiendas: 20 },
  { id: 'metropolis', nombre: 'Metrópolis (Masiva)', maxTiendas: 35 }
]

const categoriasTiendas = {
  "Comercio y Artesanía": ["Herrería", "Carpintería", "Sastrería", "Joyería", "Alfarería", "Mercado General"],
  "Magia": ["Alquimia", "Tienda Arcana", "Biblioteca Arcana", "Adivino / Oráculo"],
  "Alimentación y Hospedaje": ["Taberna", "Posada", "Panadería", "Carnicería", "Cervecería / Bodega"],
  "Aventureros": ["Gremio de Aventureros", "Tienda de Suministros", "Cartógrafo", "Casa de Recompensas", "Casa de Subastas"],
  "Animales y Transporte": ["Establo", "Criador de Monturas", "Puerto / Dársena"],
  "Religión y Conocimiento": ["Templo", "Monasterio", "Biblioteca", "Academia de Magia"],
  "Servicios": ["Banco", "Curandero", "Baños Públicos", "Notaría / Registro"],
  "Entretenimiento": ["Teatro", "Arena de Combate", "Casino / Casa de Juegos"],
  "Gobierno": ["Ayuntamiento", "Cuartel de Guardias", "Prisión", "Tribunal"],
  "Mercado Negro": ["Mercado Negro", "Gremio de Ladrones", "Contrabandista"]
}

// --- ESTADOS DE VISTA ---
const vista = ref('lista') // 'lista' | 'crear' | 'ciudad-detalle' | 'tienda-detalle'
const ciudades = ref([])
const tiendasDeCiudadActual = ref([])
const ciudadActiva = ref(null)
const tiendaActiva = ref(null)
const npcDeTienda = ref(null)

// --- BUSCADORES Y FILTROS ---
const busquedaTienda = ref('')

const tiendasFiltradas = computed(() => {
  return tiendasDeCiudadActual.value.filter(t => 
    (t.nombre_personalizado || t.tipo).toLowerCase().includes(busquedaTienda.value.toLowerCase())
  )
})

// --- FORMULARIOS ---
const formCiudad = ref({ nombre: '', tamano: 'pueblo', descripcion: '' })
const tiendasSeleccionadasParaCrear = ref([])
const nuevoItemForm = ref({ nombre: '', cantidad: 1, precio_cobre: 100, bono: '' })

// --- AUTOSELECCIÓN PROCEDURAL ---
const autoSeleccionarTiendas = () => {
  tiendasSeleccionadasParaCrear.value = []
  const max = tamanos.find(t => t.id === formCiudad.value.tamano).maxTiendas
  let opcionesBase = ['Mercado General', 'Taberna', 'Herrería', 'Templo', 'Posada']
  opcionesBase.forEach(t => { if(tiendasSeleccionadasParaCrear.value.length < max) tiendasSeleccionadasParaCrear.value.push(t) })
  const todas = Object.values(categoriasTiendas).flat()
  while(tiendasSeleccionadasParaCrear.value.length < max) {
    let r = todas[Math.floor(Math.random() * todas.length)]
    if(!tiendasSeleccionadasParaCrear.value.includes(r)) tiendasSeleccionadasParaCrear.value.push(r)
  }
}

// --- CRUD ASENTAMIENTOS (CIUDADES) ---
const cargarCiudades = async () => {
  const { data } = await supabase.from('ciudades').select('*').order('nombre')
  if (data) ciudades.value = data
}

const crearCiudad = async () => {
  if (!formCiudad.value.nombre) return alert("Ponle un nombre al asentamiento.")
  
  // 1. Guardar la ciudad primero
  const { data: nuevaCiu, error: errCiudad } = await supabase.from('ciudades').insert([{
    nombre: formCiudad.value.nombre,
    tamano: formCiudad.value.tamano,
    descripcion: formCiudad.value.descripcion
  }]).select().single()
  
  if (errCiudad) return alert("Error al crear ciudad: " + errCiudad.message)

  // 2. Preparar el array de tiendas
  const tAInsertar = tiendasSeleccionadasParaCrear.value.map(tipoLugar => ({
    ciudad_id: nuevaCiu.id,
    campaign_id: route.params.id || null, 
    nombre_personalizado: `${tipoLugar} de ${nuevaCiu.nombre}`,
    tipo: tipoLugar, // <--- Este campo es el que está dando el error
    inventario_actual: []
  }))

  // 3. Insertar las tiendas y ATRAER EL ERROR si lo hay
  if(tAInsertar.length > 0) {
    const { error: errTiendas } = await supabase.from('tiendas_sesion').insert(tAInsertar)
    if (errTiendas) {
      console.error("Error SQL en tiendas:", errTiendas)
      return alert("Ciudad creada, pero fallaron las tiendas: " + errTiendas.message)
    }
  }

  alert("¡Asentamiento y comercios fundados con éxito!")
  vista.value = 'lista'; 
  cargarCiudades()
}

const abrirCiudad = async (ciudad) => {
  ciudadActiva.value = ciudad
  busquedaTienda.value = ''
  
  // Agregamos manejo de error acá también por si falla el select
  const { data, error } = await supabase.from('tiendas_sesion').select('*').eq('ciudad_id', ciudad.id).order('tipo')
  
  if (error) {
    console.error("Error cargando locales:", error)
    alert("Error cargando los locales de esta ciudad: " + error.message)
  }
  
  if (data) tiendasDeCiudadActual.value = data
  vista.value = 'ciudad-detalle'
}

const guardarCambiosCiudad = async () => {
  await supabase.from('ciudades').update({
    nombre: ciudadActiva.value.nombre,
    descripcion: ciudadActiva.value.descripcion
  }).eq('id', ciudadActiva.value.id)
  alert("Ciudad actualizada.")
}

const borrarCiudad = async (id) => {
  if(confirm("¿Estás seguro de borrar este asentamiento entero con todas sus tiendas instaladas?")) {
    await supabase.from('ciudades').delete().eq('id', id)
    vista.value = 'lista'; cargarCiudades()
  }
}

// --- CRUD TIENDAS ---

const abrirTienda = async (tienda) => {
  tiendaActiva.value = tienda
  npcDeTienda.value = null
  if(!tiendaActiva.value.inventario_actual) tiendaActiva.value.inventario_actual = []
  
  if (tienda.npc_id) {
    const { data } = await supabase.from('characters').select('*').eq('id', tienda.npc_id).single()
    if (data) npcDeTienda.value = data
  }
  vista.value = 'tienda-detalle'
}

const guardarCambiosTienda = async () => {
  await supabase.from('tiendas_sesion').update({
    nombre_personalizado: tiendaActiva.value.nombre_personalizado,
    imagen_url: tiendaActiva.value.imagen_url,
    inventario_actual: tiendaActiva.value.inventario_actual
  }).eq('id', tiendaActiva.value.id)
  alert("Establecimiento guardado.")
}

const borrarTienda = async () => {
  if(confirm("¿Demoler este establecimiento por completo?")) {
    await supabase.from('tiendas_sesion').delete().eq('id', tiendaActiva.value.id)
    abrirCiudad(ciudadActiva.value)
  }
}

// --- INVENTARIOS ACTIVO ---
const agregarObjetoALocal = async () => {
  if(!nuevoItemForm.value.nombre) return alert("Escribe el nombre del objeto.")
  
  const nuevoItem = {
    id: Date.now() + Math.random(),
    nombre: nuevoItemForm.value.nombre,
    cantidad: parseInt(nuevoItemForm.value.cantidad) || 1,
    precio_cobre: parseInt(nuevoItemForm.value.precio_cobre) || 0,
    bono: nuevoItemForm.value.bono || null
  }

  tiendaActiva.value.inventario_actual.push(nuevoItem)
  await supabase.from('tiendas_sesion').update({ inventario_actual: tiendaActiva.value.inventario_actual }).eq('id', tiendaActiva.value.id)
  
  // Limpiar form
  nuevoItemForm.value = { nombre: '', cantidad: 1, precio_cobre: 100, bono: '' }
}

const eliminarObjetoDeLocal = async (itemId) => {
  tiendaActiva.value.inventario_actual = tiendaActiva.value.inventario_actual.filter(i => i.id !== itemId)
  await supabase.from('tiendas_sesion').update({ inventario_actual: tiendaActiva.value.inventario_actual }).eq('id', tiendaActiva.value.id)
}

// --- LOGICA NPC ---
const mostrandoModalNPC = ref(false)
const vincularNpcATienda = async (npcGuardado) => {
  mostrandoModalNPC.value = false
  await supabase.from('tiendas_sesion').update({ npc_id: npcGuardado.id }).eq('id', tiendaActiva.value.id)
  npcDeTienda.value = npcGuardado
  tiendaActiva.value.npc_id = npcGuardado.id
}

onMounted(() => { cargarCiudades() })
</script>

<template>
  <div class="gestor-wrapper">
    
    <div class="header-gestor">
      <h2 class="titulo-principal">
        <span v-if="vista === 'lista'">🌍 ATLAS DE LA CAMPAÑA</span>
        <span v-if="vista === 'crear'">🏗️ FUNDAR ASENTAMIENTO</span>
        <span v-if="vista === 'ciudad-detalle'">🏰 URBANISMO: {{ ciudadActiva?.nombre }}</span>
        <span v-if="vista === 'tienda-detalle'">🏪 COMERCIO INTERNO</span>
      </h2>
      <div class="acciones-header">
        <button v-if="vista !== 'lista'" class="btn-secundario" @click="vista = 'lista'">🗺️ Volver al Atlas</button>
        <button v-if="vista === 'lista'" class="btn-dorado" @click="vista = 'crear'; autoSeleccionarTiendas()">+ Fundar Lugar</button>
      </div>
    </div>

    <div v-if="vista === 'lista'" class="grilla-ciudades">
      <div v-if="ciudades.length === 0" class="mensaje-vacio">El atlas está vacío. Comienza fundando una aldea o ciudad.</div>
      <div v-for="c in ciudades" :key="c.id" class="card-ciudad" @click="abrirCiudad(c)">
        <div class="icono-ciudad">🏰</div>
        <div class="info-ciudad">
          <h3>{{ c.nombre }}</h3>
          <span class="tamano-etiqueta">{{ c.tamano.toUpperCase() }}</span>
        </div>
      </div>
    </div>

    <div v-if="vista === 'crear'" class="vista-creacion">
      <div class="form-basico">
        <div class="input-group">
          <label>Nombre del Lugar</label>
          <input type="text" v-model="formCiudad.nombre" class="input-dm" placeholder="Ej: Fuerte Roca Negra" />
        </div>
        <div class="input-group">
          <label>Magnitud / Tamaño</label>
          <select v-model="formCiudad.tamano" @change="autoSeleccionarTiendas" class="input-dm">
            <option v-for="t in tamanos" :key="t.id" :value="t.id">{{ t.nombre }}</option>
          </select>
        </div>
      </div>

      <div class="selector-tiendas">
        <h3>Locales recomendados automáticamente ({{ tiendasSeleccionadasParaCrear.length }} activos)</h3>
        <div class="grilla-categorias">
          <div v-for="(lugares, cat) in categoriasTiendas" :key="cat" class="categoria-box">
            <h4>{{ cat }}</h4>
            <label v-for="l in lugares" :key="l" class="checkbox-lugar">
              <input type="checkbox" :value="l" v-model="tiendasSeleccionadasParaCrear" />
              <span>{{ l }}</span>
            </label>
          </div>
        </div>
      </div>
      <button class="btn-dorado gigante" @click="crearCiudad">Fundar e Inyectar Mapa</button>
    </div>

    <div v-if="vista === 'ciudad-detalle' && ciudadActiva" class="vista-detalle-ciudad">
      <div class="panel-edicion-ciudad">
        <div class="inputs-inline">
          <input v-model="ciudadActiva.nombre" class="input-dm edit-title" />
          <button @click="guardarCambiosCiudad" class="btn-dorado">💾 Guardar Nombre</button>
          <button @click="borrarCiudad(ciudadActiva.id)" class="btn-rojo">🔥 Destruir Ciudad</button>
        </div>
        <textarea v-model="ciudadActiva.descripcion" placeholder="Notas sobre el pueblo..." class="input-dm txt-area mt-1"></textarea>
      </div>

      <div class="barra-busqueda-tiendas">
        <input type="text" v-model="busquedaTienda" placeholder="🔍 Buscar establecimiento en esta ciudad..." class="input-dm search-bar" />
      </div>

      <div class="grilla-tiendas">
        <div v-for="t in tiendasFiltradas" :key="t.id" class="card-tienda" @click="addNPC = false; abrirTienda(t)">
          <img v-if="t.imagen_url" :src="t.imagen_url" class="img-tienda-real" />
          <div v-else class="icono-tienda">🏠</div>
          
          <h4>{{ t.nombre_personalizado || t.tipo }}</h4>
          <span class="etiqueta-tipo">{{ t.tipo }}</span>
          <div :class="['indicador-npc', t.npc_id ? 'ok' : 'vacio']">
            {{ t.npc_id ? '👤 Atendida' : '⚠️ Sin Tendero' }}
          </div>
        </div>
      </div>
    </div>

    <div v-if="vista === 'tienda-detalle' && tiendaActiva" class="vista-tienda-interna">
      <div class="header-tienda-interna">
        <button class="btn-secundario" @click="abrirCiudad(ciudadActiva)">⬅ Regresar a las calles</button>
        <div class="inputs-tienda-crud mt-1">
          <div class="input-group flex-2">
            <label>Nombre Comercial</label>
            <input v-model="tiendaActiva.nombre_personalizado" class="input-dm" />
          </div>
          <div class="input-group flex-2">
            <label>URL de Imagen del Negocio</label>
            <input v-model="tiendaActiva.imagen_url" class="input-dm" placeholder="https://..." />
          </div>
          <div class="botones-tienda-fns">
            <button @click="guardarCambiosTienda" class="btn-dorado">💾 Guardar Local</button>
            <button @click="borrarTienda" class="btn-rojo">❌ Demoler</button>
          </div>
        </div>
      </div>

      <div class="paneles-tienda">
        <div class="panel-npc">
          <h3>Encargado / Dependiente</h3>
          <div v-if="npcDeTienda" class="tarjeta-npc-asignado">
            <div class="avatar-npc">👤</div>
            <div class="info-npc-asignado">
              <h4>{{ npcDeTienda.nombre_pj }}</h4>
              <p>{{ npcDeTienda.raza }} {{ npcDeTienda.clase }} | Nivel {{ npcDeTienda.nivel }}</p>
              <div class="stats-mini">HP: {{ npcDeTienda.hp_max }} | CA: {{ npcDeTienda.clase_armadura }}</div>
            </div>
          </div>
          <div v-else class="tarjeta-sin-npc">
            <p class="txt-gris">Local desatendido. Las transacciones usarán un dependiente genérico nivel 3.</p>
            <button @click="mostrandoModalNPC = true" class="btn-dorado mt-1">✨ Contratar/Crear NPC</button>
          </div>
        </div>

        <div class="panel-inventario">
          <h3>Cajas e Inventario Comercial</h3>
          
          <div class="form-agregar-item-tienda">
            <input type="text" v-model="nuevoItemForm.nombre" placeholder="Nombre del artículo..." class="input-dm compact" />
            <input type="number" v-model="nuevoItemForm.cantidad" placeholder="Cant." class="input-dm compact short" />
            <input type="number" v-model="nuevoItemForm.precio_cobre" placeholder="Precio (Cobre)" class="input-dm compact short" />
            <input type="text" v-model="nuevoItemForm.bono" placeholder="Bono/Daño" class="input-dm compact short" />
            <button @click="agregarObjetoALocal" class="btn-dorado comp">+ Inyectar</button>
          </div>

          <div class="tabla-inventario-scroll mt-1">
            <div v-if="tiendaActiva.inventario_actual.length === 0" class="txt-gris txt-centro padding-largo">Estanterías vacías. Agrega ítems arriba para poblar el comercio.</div>
            <div v-for="item in tiendaActiva.inventario_actual" :key="item.id" class="fila-item-tienda-interna">
              <span class="it-cant">x{{ item.cantidad }}</span>
              <span class="it-nom"><strong>{{ item.nombre }}</strong> <small v-if="item.bono">({{ item.bono }})</small></span>
              <span class="it-precio">💰 {{ item.precio_cobre }} pc</span>
              <button @click="eliminarObjetoDeLocal(item.id)" class="btn-borrar-item-tabla">✖</button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <ModalGeneradorNpc 
      v-if="mostrandoModalNPC" 
      :tiendaFijaId="tiendaActiva?.id" 
      :tiendaTipo="tiendaActiva?.tipo"
      @cerrar="mostrandoModalNPC = false" 
      @guardar-npc="vincularNpcATienda" 
    />
  </div>
</template>

<style scoped>
.gestor-wrapper { padding: 20px; color: #e2e8f0; font-family: 'Inter', sans-serif; }
.header-gestor { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #1e293b; padding-bottom: 15px; margin-bottom: 20px; }
.titulo-principal { font-family: 'Cinzel', serif; color: #facc15; font-size: 1.6rem; margin: 0; }
.btn-dorado { background: #b45309; border: 1px solid #f59e0b; color: white; padding: 8px 16px; font-family: 'Cinzel', serif; font-weight: bold; border-radius: 6px; cursor: pointer; transition: 0.2s; }
.btn-dorado:hover { background: #d97706; box-shadow: 0 0 10px rgba(245,158,11,0.4); }
.btn-dorado.gigante { width: 100%; padding: 12px; font-size: 1.1rem; }
.btn-secundario { background: transparent; border: 1px solid #475569; color: #cbd5e1; padding: 8px 16px; border-radius: 6px; cursor: pointer; font-weight: bold; }
.btn-rojo { background: #7f1d1d; border: 1px solid #ef4444; color: white; padding: 8px 16px; border-radius: 6px; cursor: pointer; font-weight: bold; }
.grilla-ciudades { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 20px; }
.card-ciudad { background: #0a0a0c; border: 1px solid #1e293b; border-radius: 10px; padding: 20px; display: flex; align-items: center; gap: 15px; cursor: pointer; transition: 0.2s; }
.card-ciudad:hover { border-color: #3b82f6; transform: translateY(-2px); }
.icono-ciudad { font-size: 2.5rem; }
.info-ciudad h3 { margin: 0 0 5px 0; font-family: 'Cinzel', serif; color: white; }
.tamano-etiqueta { background: rgba(59, 130, 246, 0.15); color: #93c5fd; padding: 2px 8px; border-radius: 12px; font-size: 0.75rem; font-weight: bold; }
.form-basico { display: grid; grid-template-columns: 2fr 1fr; gap: 20px; margin-bottom: 20px; }
.input-group { display: flex; flex-direction: column; gap: 4px; }
.input-group.flex-2 { flex: 2; }
.input-group label { font-size: 0.85rem; color: #94a3b8; font-weight: bold; }
.input-dm { background: #0a0a0c; border: 1px solid #334155; color: white; padding: 10px; border-radius: 6px; outline: none; font-size: 1rem; width: 100%; }
.input-dm:focus { border-color: #facc15; }
.input-dm.edit-title { font-family: 'Cinzel', serif; font-size: 1.5rem; color: #facc15; flex: 1; }
.selector-tiendas { background: #0a0a0c; padding: 20px; border-radius: 10px; border: 1px solid #1e293b; margin-bottom: 20px; }
.grilla-categorias { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 15px; }
.categoria-box { background: #111; padding: 12px; border-radius: 6px; border: 1px solid #27272a; }
.categoria-box h4 { color: #facc15; margin: 0 0 10px 0; font-family: 'Cinzel', serif; border-bottom: 1px solid #27272a; padding-bottom: 4px; }
.checkbox-lugar { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; font-size: 0.85rem; cursor: pointer; }
.checkbox-lugar input { accent-color: #facc15; }
.panel-edicion-ciudad { background: #0a0a0c; border: 1px solid #1e293b; padding: 15px; border-radius: 8px; margin-bottom: 15px; }
.inputs-inline { display: flex; gap: 10px; align-items: center; width: 100%; }
.barra-busqueda-tiendas { margin-bottom: 15px; }
.input-dm.search-bar { border-color: #3b82f6; background: #050505; font-size: 1.1rem; }
.grilla-tiendas { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 15px; }
.card-tienda { background: #0a0a0c; border: 1px solid #1e293b; padding: 15px; border-radius: 8px; text-align: center; cursor: pointer; transition: 0.2s; overflow: hidden; }
.card-tienda:hover { border-color: #facc15; }
.icono-tienda { font-size: 2rem; margin-bottom: 8px; }
.img-tienda-real { width: 100%; height: 100px; object-fit: cover; border-radius: 6px; margin-bottom: 8px; border: 1px solid #27272a; }
.card-tienda h4 { margin: 0 0 5px 0; font-size: 0.95rem; color: white; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.etiqueta-tipo { font-size: 0.7rem; color: #94a3b8; background: #1e293b; padding: 1px 6px; border-radius: 10px; }
.indicador-npc { margin-top: 10px; font-size: 0.75rem; font-weight: bold; padding: 3px; border-radius: 4px; }
.indicador-npc.ok { color: #4ade80; background: rgba(74,222,128,0.1); }
.indicador-npc.vacio { color: #f59e0b; background: rgba(245,158,11,0.1); }
.inputs-tienda-crud { display: flex; gap: 15px; align-items: flex-end; background: #0a0a0c; padding: 15px; border-radius: 8px; border: 1px solid #1e293b; flex-wrap: wrap; }
.botones-tienda-fns { display: flex; gap: 10px; }
.paneles-tienda { display: grid; grid-template-columns: 280px 1fr; gap: 20px; margin-top: 20px; align-items: start; }
.panel-npc, .panel-inventario { background: #0a0a0c; border: 1px solid #1e293b; border-radius: 10px; padding: 15px; }
.panel-npc h3, .panel-inventario h3 { margin: 0 0 12px 0; font-family: 'Cinzel', serif; color: #facc15; font-size: 1.1rem; border-bottom: 1px solid #1e293b; padding-bottom: 6px; }
.tarjeta-sin-npc { border: 1px dashed #475569; padding: 15px; border-radius: 6px; text-align: center; font-size: 0.85rem; }
.tarjeta-npc-asignado { display: flex; gap: 10px; background: rgba(59,130,246,0.1); border: 1px solid #3b82f6; padding: 12px; border-radius: 6px; }
.avatar-npc { font-size: 2rem; }
.info-npc-asignado h4 { margin: 0 0 2px 0; font-family: 'Cinzel', serif; color: white; }
.info-npc-asignado p { margin: 0 0 6px 0; font-size: 0.8rem; color: #94a3b8; }
.stats-mini { font-size: 0.75rem; color: #facc15; font-weight: bold; }
.form-agregar-item-tienda { display: flex; gap: 8px; width: 100%; background: #111; padding: 10px; border-radius: 6px; border: 1px solid #27272a; }
.input-dm.compact { padding: 6px; font-size: 0.85rem; }
.input-dm.compact.short { width: 80px; text-align: center; }
.btn-dorado.comp { font-size: 0.8rem; padding: 6px 12px; font-family: sans-serif; }
.tabla-inventario-scroll { max-height: 350px; overflow-y: auto; display: flex; flex-direction: column; gap: 6px; }
.fila-item-tienda-interna { display: flex; align-items: center; background: #111; border: 1px solid #27272a; padding: 8px; border-radius: 6px; font-size: 0.9rem; }
.it-cant { color: #fca5a5; font-weight: bold; width: 40px; }
.it-nom { flex: 1; color: white; }
.it-precio { color: #facc15; font-weight: bold; font-family: monospace; padding-right: 10px; }
.btn-borrar-item-tabla { background: transparent; border: none; color: #ef4444; cursor: pointer; font-weight: bold; }
.btn-borrar-item-tabla:hover { color: #f87171; }
.txt-gris { color: #94a3b8; font-size: 0.85rem; }
.txt-centro { text-align: center; }
.padding-largo { padding: 30px 10px; }
.mt-1 { margin-top: 10px; }
</style>