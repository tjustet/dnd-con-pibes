export function useAvisos() {
  const aviso = useState('aviso-partida', () => null)
  function avisar(texto, error = false) {
    aviso.value = { texto, error, id: (aviso.value?.id ?? 0) + 1 }
  }
  return { aviso, avisar }
}
