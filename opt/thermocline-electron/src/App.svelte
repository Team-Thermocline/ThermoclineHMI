<script>
  import Sender from '../team-thermocline.github.io/src/sender/Sender.svelte';
</script>

<Sender />

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    overflow: hidden;
    width: 100vw;
    height: 100vh;
    background: var(--bg, #0a0a0b);
    color: var(--text, #e6e6e6);
  }

  :global(html) {
    margin: 0;
    padding: 0;
    width: 100vw;
    height: 100vh;
    background: var(--bg, #0a0a0b);
    color: var(--text, #e6e6e6);
  }

  :global(#app) {
    width: 100vw;
    height: 100vh;
    background: var(--bg, #0a0a0b);
  }
</style>
