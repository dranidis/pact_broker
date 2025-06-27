function toggleAllDetails() {
    const details = document.querySelectorAll('details');
    const allOpen = Array.from(details).every(d => d.open);
    const shouldOpen = !allOpen;

    details.forEach(d => {
    if (shouldOpen) {
        d.setAttribute('open', '');
    } else {
        d.removeAttribute('open');
    }
    });

    const button = document.getElementById('toggle-all');
    button.textContent = shouldOpen ? 'Collapse All' : 'Expand All';
}

function showToast(message, isError = false) {
    const toastEl = document.getElementById('downloadToast');
    const toastBody = toastEl.querySelector('.toast-body');
    toastBody.textContent = message;
    
    if (isError) {
        toastEl.classList.add('error');
    } else {
        toastEl.classList.remove('error');
    }
    
    const toast = new bootstrap.Toast(toastEl, { delay: 3000 });
    toast.show();
}

function updateDownloadButtonState() {
    const allCheckboxes = Array.from(document.querySelectorAll('.interaction-checkbox'));
    const hasChecked = allCheckboxes.some(cb => cb.checked);
    const hasInteractions = allCheckboxes.length > 0;
    
    document.getElementById('download-selected').disabled = !hasChecked;
    
    if (hasInteractions) {
        document.body.classList.remove('no-interactions');
    } else {
        document.body.classList.add('no-interactions');
    }
}

document.addEventListener('DOMContentLoaded', function() {
    updateDownloadButtonState();

    document.querySelectorAll('.interaction-checkbox').forEach(checkbox => {
        checkbox.addEventListener('change', updateDownloadButtonState);
    });

    const downloadSelectedBtn = document.getElementById('download-selected');
    const downloadAllBtn = document.getElementById('download-all');
    const fullPactScript = document.getElementById('full-pact-json');
    const fullPactJson = fullPactScript ? JSON.parse(fullPactScript.textContent) : null;

    // Normalize provider states for comparison
    function normalizeProviderStates(states) {
        if (!states) return [];
        const statesArray = Array.isArray(states) ? states : [];
        return statesArray.map(state => ({
        name: state.name || state.name
        }));
    }

    // Find matching interaction in full pact
    function findMatchingInteraction(selectedInteraction, fullPactInteractions) {
        return fullPactInteractions.find(fullInteraction => {
        const descriptionMatch = fullInteraction.description === selectedInteraction.description;
        const selectedStates = normalizeProviderStates(selectedInteraction.provider_states || selectedInteraction.providerStates);
        const fullStates = normalizeProviderStates(fullInteraction.provider_states || fullInteraction.providerStates);
        const statesMatch = selectedStates.length === fullStates.length &&
            selectedStates.every((state, index) => state.name === fullStates[index].name);
        return descriptionMatch && statesMatch;
        });
    }

    downloadSelectedBtn.addEventListener('click', function() {
        const selectedCheckboxes = document.querySelectorAll('.interaction-checkbox:checked');

        if (selectedCheckboxes.length === 0) {
        showToast('No interactions selected.', true);
        return;
        }

        const selectedInteractions = Array.from(selectedCheckboxes).map(cb => {
        const rawJson = cb.getAttribute('data-interaction-json');
        const parsedInteraction = JSON.parse(rawJson);
        const { provider_states, ...rest } = parsedInteraction;

        let base = {
            ...rest,
            ...(provider_states !== undefined ? { providerStates: provider_states } : {})
        };

        // If we have the full pact, try to merge with matching interaction
        if (fullPactJson ) {
            if (!fullPactJson.interactions) {
            fullPactJson.interactions = fullPactJson.messages || [];
            }
            const matchingInteraction = findMatchingInteraction(parsedInteraction, fullPactJson.interactions);
            if (matchingInteraction) {
            return matchingInteraction;
            }
        }
        return base;
        });

        const pactJson = {
        consumer: fullPactJson?.consumer,
        provider: fullPactJson?.provider,
        ...(fullPactJson?.messages
            ? { messages: selectedInteractions }
            : { interactions: selectedInteractions }),
        metadata: fullPactJson?.metadata
        };

        const pactName = (pactJson.consumer?.name && pactJson.provider?.name) ? 
        `${pactJson.consumer.name}-to-${pactJson.provider.name}` : 'pact';
        const filename = `selectedInteractions-${pactName}.json`;

        const blob = new Blob([JSON.stringify(pactJson, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);

        showToast(`Downloaded ${selectedInteractions.length} interaction(s).`);
        selectedCheckboxes.forEach(cb => cb.checked = false);
        updateDownloadButtonState();
    });

    // Download all interactions
    downloadAllBtn.addEventListener('click', function() {
        const pactScript = document.getElementById('full-pact-json');
        try {
        const pactJson = JSON.parse(pactScript.textContent);
        const pactName = (pactJson.consumer?.name && pactJson.provider?.name) ? 
            `${pactJson.consumer.name}-to-${pactJson.provider.name}` : 'pact';
        const filename = `allInteractions-${pactName}.json`;
        const blob = new Blob([JSON.stringify(pactJson, null, 2)], {type: 'application/json'});
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        showToast('Downloaded all interactions.');
        } catch (e) {
        showToast('Could not parse full pact JSON.', true);
        }
    });
});