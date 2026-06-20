// Injects the shared nav. Call renderNav(currentPage) at the top of <body>.
// currentPage: 'home' | 'schedule' | 'tools' | 'lab-util' | 'lab-syscall' | ...
function renderNav(currentPage) {
  const labs = [
    { slug: 'tools',    label: 'Tools',              file: '../tools.html' },
    { slug: 'guidance', label: 'Guidance',            file: 'guidance.html' },
    { slug: 'util',     label: 'Lab: Utilities',      file: 'util.html' },
    { slug: 'syscall',  label: 'Lab: System Calls',   file: 'syscall.html' },
    { slug: 'pgtbl',    label: 'Lab: Page Tables',    file: 'pgtbl.html' },
    { slug: 'traps',    label: 'Lab: Traps',          file: 'traps.html' },
    { slug: 'cow',      label: 'Lab: Copy-on-Write',  file: 'cow.html' },
    { slug: 'thread',   label: 'Lab: Multithreading', file: 'thread.html' },
    { slug: 'net',      label: 'Lab: Network Driver', file: 'net.html' },
    { slug: 'lock',     label: 'Lab: Locks',          file: 'lock.html' },
    { slug: 'fs',       label: 'Lab: File System',    file: 'fs.html' },
    { slug: 'mmap',     label: 'Lab: Mmap',           file: 'mmap.html' },
  ];

  // Resolve relative path prefix depending on whether we are in labs/ subdir
  const inLabs = window.location.pathname.includes('/labs/');
  const root   = inLabs ? '../' : '';
  const labDir = inLabs ? ''    : 'labs/';

  const labItems = labs.map(l => {
    const href = l.slug === 'tools' ? root + 'tools.html'
               : labDir + l.slug + '.html';
    const active = currentPage === 'lab-' + l.slug || currentPage === l.slug;
    return `<a href="${href}"${active ? ' class="active"' : ''}>${l.label}</a>`;
  }).join('\n        ');

  document.write(`
<nav>
  <div class="nav-inner">
    <a class="brand" href="${root}index.html">6.S081 <span>/ OS Engineering</span></a>
    <a class="nav-link${currentPage==='home'?' active':''}" href="${root}index.html">Home</a>
    <a class="nav-link${currentPage==='schedule'?' active':''}" href="${root}schedule.html">Schedule</a>
    <div class="nav-dropdown">
      <a class="nav-link${currentPage.startsWith('lab')?' active':''}">Labs</a>
      <div class="dropdown-menu">
        ${labItems}
      </div>
    </div>
    <a class="nav-link" href="https://pdos.csail.mit.edu/6.S081/2021/" target="_blank" title="Original MIT site">MIT ↗</a>
  </div>
</nav>`);
}
