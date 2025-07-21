// Global state
let appData = {
    status: 'unknown',
    healthData: null,
    clusters: [],
    deployments: []
};

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    initializeNavigation();
    loadDashboardData();
    setInterval(updateStatusIndicator, 30000); // Update every 30 seconds
});

// Navigation handling
function initializeNavigation() {
    const navButtons = document.querySelectorAll('.nav-btn');
    const tabContents = document.querySelectorAll('.tab-content');

    navButtons.forEach(button => {
        button.addEventListener('click', () => {
            const targetTab = button.getAttribute('data-tab');
            
            // Update active navigation button
            navButtons.forEach(btn => btn.classList.remove('active'));
            button.classList.add('active');
            
            // Update active tab content
            tabContents.forEach(tab => tab.classList.remove('active'));
            document.getElementById(targetTab).classList.add('active');
            
            // Load tab-specific data
            loadTabData(targetTab);
        });
    });
}

// Load data for specific tabs
function loadTabData(tab) {
    switch(tab) {
        case 'dashboard':
            loadDashboardData();
            break;
        case 'clusters':
            loadClusters();
            break;
        case 'deployments':
            loadDeployments();
            break;
        case 'monitoring':
            // Monitoring links are static
            break;
        case 'logs':
            loadLogs();
            break;
        case 'health':
            loadHealthData();
            break;
    }
}

// Dashboard functions
async function loadDashboardData() {
    try {
        // Load system status
        const healthResponse = await fetch('/health');
        const healthData = await healthResponse.json();
        
        updateDashboard(healthData);
        updateStatusIndicator('healthy');
        
    } catch (error) {
        console.error('Error loading dashboard data:', error);
        updateStatusIndicator('error');
        showError('Failed to load dashboard data');
    }
}

function updateDashboard(data) {
    // Update system metrics
    document.getElementById('uptime').textContent = data.uptime || 'Unknown';
    document.getElementById('environment').textContent = data.environment || 'Unknown';
    document.getElementById('version').textContent = data.version || 'Unknown';
    
    // Update memory usage
    if (data.memory) {
        document.getElementById('memory').textContent = data.memory.used || 'Unknown';
        document.getElementById('heap').textContent = data.memory.heap ? 
            `${data.memory.heap.used} / ${data.memory.heap.total}` : 'Unknown';
    }
    
    // Update service status
    document.getElementById('database-status').textContent = 
        data.database?.status === 'connected' ? '✅ Connected' : '❌ Disconnected';
    document.getElementById('redis-status').textContent = '✅ Connected'; // Placeholder
    document.getElementById('monitoring-status').textContent = '✅ Active'; // Placeholder
}

function updateStatusIndicator(status) {
    const statusDot = document.getElementById('status-dot');
    const statusText = document.getElementById('status-text');
    
    statusDot.className = 'status-dot';
    
    switch(status) {
        case 'healthy':
            statusDot.classList.add('healthy');
            statusText.textContent = 'System Healthy';
            appData.status = 'healthy';
            break;
        case 'warning':
            statusDot.classList.add('warning');
            statusText.textContent = 'System Warning';
            appData.status = 'warning';
            break;
        case 'error':
            statusDot.classList.add('error');
            statusText.textContent = 'System Error';
            appData.status = 'error';
            break;
        default:
            statusText.textContent = 'Checking...';
            appData.status = 'unknown';
    }
}

// Clusters functions
async function loadClusters() {
    const container = document.getElementById('clusters-list');
    container.innerHTML = '<div class="loading-message">Loading clusters...</div>';
    
    try {
        // Simulate cluster data (replace with actual API call)
        const clusters = [
            {
                name: 'development-cluster',
                status: 'active',
                nodes: 3,
                version: 'v1.28.2',
                provider: 'local'
            },
            {
                name: 'staging-cluster',
                status: 'inactive',
                nodes: 0,
                version: 'v1.28.2',
                provider: 'aws'
            },
            {
                name: 'production-cluster',
                status: 'inactive',
                nodes: 0,
                version: 'v1.28.2',
                provider: 'aws'
            }
        ];
        
        appData.clusters = clusters;
        renderClusters(clusters);
        
    } catch (error) {
        console.error('Error loading clusters:', error);
        container.innerHTML = '<div class="error-message">Failed to load clusters</div>';
    }
}

function renderClusters(clusters) {
    const container = document.getElementById('clusters-list');
    
    if (clusters.length === 0) {
        container.innerHTML = '<div class="empty-message">No clusters found</div>';
        return;
    }
    
    container.innerHTML = clusters.map(cluster => `
        <div class="cluster-card">
            <div class="cluster-header">
                <h3>${cluster.name}</h3>
                <span class="cluster-status ${cluster.status}">${cluster.status}</span>
            </div>
            <div class="cluster-details">
                <div class="detail-item">
                    <span class="label">Nodes:</span>
                    <span class="value">${cluster.nodes}</span>
                </div>
                <div class="detail-item">
                    <span class="label">Version:</span>
                    <span class="value">${cluster.version}</span>
                </div>
                <div class="detail-item">
                    <span class="label">Provider:</span>
                    <span class="value">${cluster.provider}</span>
                </div>
            </div>
            <div class="cluster-actions">
                <button class="btn btn-primary btn-sm" onclick="viewCluster('${cluster.name}')">
                    <i class="fas fa-eye"></i> View
                </button>
                <button class="btn btn-secondary btn-sm" onclick="manageCluster('${cluster.name}')">
                    <i class="fas fa-cog"></i> Manage
                </button>
            </div>
        </div>
    `).join('');
}

function refreshClusters() {
    loadClusters();
}

function createCluster() {
    showDialog('Create New Cluster', `
        <form id="create-cluster-form">
            <div class="form-group">
                <label for="cluster-name">Cluster Name:</label>
                <input type="text" id="cluster-name" name="name" required>
            </div>
            <div class="form-group">
                <label for="cluster-provider">Provider:</label>
                <select id="cluster-provider" name="provider" required>
                    <option value="local">Local (Kind)</option>
                    <option value="aws">AWS EKS</option>
                    <option value="gcp">Google GKE</option>
                    <option value="azure">Azure AKS</option>
                </select>
            </div>
            <div class="form-group">
                <label for="cluster-nodes">Node Count:</label>
                <input type="number" id="cluster-nodes" name="nodes" min="1" max="10" value="3">
            </div>
        </form>
    `, 'Create Cluster', () => {
        const formData = new FormData(document.getElementById('create-cluster-form'));
        const clusterData = Object.fromEntries(formData);
        
        // Simulate cluster creation
        showNotification('Cluster creation initiated', 'success');
        setTimeout(() => {
            refreshClusters();
        }, 2000);
    });
}

function viewCluster(clusterName) {
    showNotification(`Viewing cluster: ${clusterName}`, 'info');
}

function manageCluster(clusterName) {
    showNotification(`Managing cluster: ${clusterName}`, 'info');
}

// Deployments functions
async function loadDeployments() {
    const container = document.getElementById('deployments-list');
    container.innerHTML = '<div class="loading-message">Loading deployments...</div>';
    
    try {
        // Simulate deployment data
        const deployments = [
            {
                name: 'rancher-ui',
                namespace: 'rancher-system',
                replicas: '3/3',
                status: 'Running',
                age: '2d'
            },
            {
                name: 'monitoring-stack',
                namespace: 'monitoring',
                replicas: '1/1',
                status: 'Running',
                age: '1d'
            }
        ];
        
        appData.deployments = deployments;
        renderDeployments(deployments);
        
    } catch (error) {
        console.error('Error loading deployments:', error);
        container.innerHTML = '<div class="error-message">Failed to load deployments</div>';
    }
}

function renderDeployments(deployments) {
    const container = document.getElementById('deployments-list');
    
    if (deployments.length === 0) {
        container.innerHTML = '<div class="empty-message">No deployments found</div>';
        return;
    }
    
    container.innerHTML = `
        <table class="table">
            <thead>
                <tr>
                    <th>Name</th>
                    <th>Namespace</th>
                    <th>Replicas</th>
                    <th>Status</th>
                    <th>Age</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                ${deployments.map(deployment => `
                    <tr>
                        <td>${deployment.name}</td>
                        <td>${deployment.namespace}</td>
                        <td>${deployment.replicas}</td>
                        <td><span class="deployment-status ${deployment.status.toLowerCase()}">${deployment.status}</span></td>
                        <td>${deployment.age}</td>
                        <td>
                            <button class="btn btn-primary btn-sm" onclick="viewDeployment('${deployment.name}')">
                                <i class="fas fa-eye"></i>
                            </button>
                            <button class="btn btn-secondary btn-sm" onclick="editDeployment('${deployment.name}')">
                                <i class="fas fa-edit"></i>
                            </button>
                        </td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;
}

function refreshDeployments() {
    loadDeployments();
}

function createDeployment() {
    showNotification('Create deployment functionality would open here', 'info');
}

function viewDeployment(deploymentName) {
    showNotification(`Viewing deployment: ${deploymentName}`, 'info');
}

function editDeployment(deploymentName) {
    showNotification(`Editing deployment: ${deploymentName}`, 'info');
}

// Logs functions
async function loadLogs() {
    const container = document.getElementById('logs-content');
    container.textContent = 'Loading logs...';
    
    try {
        // Simulate log loading
        const logs = `
[2025-07-21T02:00:00Z] INFO: Rancher Deployment Platform started
[2025-07-21T02:00:01Z] INFO: Database connection established
[2025-07-21T02:00:02Z] INFO: Monitoring services initialized
[2025-07-21T02:00:03Z] INFO: Server listening on port 8080
[2025-07-21T02:01:00Z] INFO: Health check completed - all systems operational
[2025-07-21T02:02:00Z] INFO: Metrics collection completed
[2025-07-21T02:03:00Z] INFO: Background tasks executed successfully
[2025-07-21T02:04:00Z] INFO: System status: healthy
[2025-07-21T02:05:00Z] INFO: Active connections: 45
[2025-07-21T02:06:00Z] INFO: Memory usage: 32.12 MB
        `.trim();
        
        container.textContent = logs;
        
    } catch (error) {
        console.error('Error loading logs:', error);
        container.textContent = 'Failed to load logs';
    }
}

function refreshLogs() {
    loadLogs();
}

function clearLogs() {
    document.getElementById('logs-content').textContent = 'Logs cleared.';
}

// Health functions
async function loadHealthData() {
    const container = document.getElementById('health-results');
    container.innerHTML = '<div class="loading-message">Loading health data...</div>';
    
    try {
        // Simulate health check data
        const healthChecks = [
            { name: 'Docker Service', status: 'pass' },
            { name: 'kubectl Installation', status: 'pass' },
            { name: 'Kubernetes Connectivity', status: 'warning' },
            { name: 'Local Application Health', status: 'pass' },
            { name: 'staging Environment', status: 'warning' },
            { name: 'production Environment', status: 'warning' },
            { name: 'Docker Compose Services (11/11 running)', status: 'pass' },
            { name: 'Prometheus', status: 'warning' },
            { name: 'Grafana', status: 'warning' },
            { name: 'Ingress Controller', status: 'warning' },
            { name: 'cert-manager', status: 'warning' },
            { name: 'Pod Security', status: 'warning' },
            { name: 'Persistent Volumes', status: 'warning' },
            { name: 'Storage Classes', status: 'warning' },
            { name: 'Backup System', status: 'warning' }
        ];
        
        appData.healthData = healthChecks;
        renderHealthResults(healthChecks);
        
    } catch (error) {
        console.error('Error loading health data:', error);
        container.innerHTML = '<div class="error-message">Failed to load health data</div>';
    }
}

function renderHealthResults(healthChecks) {
    const container = document.getElementById('health-results');
    
    const passCount = healthChecks.filter(check => check.status === 'pass').length;
    const totalCount = healthChecks.length;
    const successRate = Math.round((passCount / totalCount) * 100);
    
    container.innerHTML = `
        <div class="health-summary">
            <h3>Health Check Summary</h3>
            <div class="health-stats">
                <div class="stat">
                    <span class="stat-label">Total Checks:</span>
                    <span class="stat-value">${totalCount}</span>
                </div>
                <div class="stat">
                    <span class="stat-label">Passed:</span>
                    <span class="stat-value">${passCount}</span>
                </div>
                <div class="stat">
                    <span class="stat-label">Success Rate:</span>
                    <span class="stat-value">${successRate}%</span>
                </div>
            </div>
        </div>
        <div class="health-details">
            ${healthChecks.map(check => `
                <div class="health-item">
                    <span class="health-name">${check.name}</span>
                    <span class="health-status ${check.status}">${check.status.toUpperCase()}</span>
                </div>
            `).join('')}
        </div>
    `;
}

async function runHealthCheck() {
    const container = document.getElementById('health-results');
    container.innerHTML = '<div class="loading-message"><div class="loading"></div> Running health check...</div>';
    
    try {
        // Simulate running health check
        await new Promise(resolve => setTimeout(resolve, 2000));
        loadHealthData();
        showNotification('Health check completed', 'success');
        
    } catch (error) {
        console.error('Error running health check:', error);
        showNotification('Health check failed', 'error');
    }
}

function downloadHealthReport() {
    if (!appData.healthData) {
        showNotification('No health data available', 'warning');
        return;
    }
    
    const reportData = {
        timestamp: new Date().toISOString(),
        systemStatus: appData.status,
        healthChecks: appData.healthData
    };
    
    const blob = new Blob([JSON.stringify(reportData, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `health-report-${new Date().toISOString().slice(0, 10)}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    
    showNotification('Health report downloaded', 'success');
}

// Utility functions
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;
    
    // Style the notification
    Object.assign(notification.style, {
        position: 'fixed',
        top: '20px',
        right: '20px',
        padding: '15px 20px',
        borderRadius: '8px',
        color: 'white',
        fontWeight: '500',
        zIndex: '9999',
        animation: 'slideIn 0.3s ease'
    });
    
    // Set background color based on type
    const colors = {
        success: '#28a745',
        error: '#dc3545',
        warning: '#ffc107',
        info: '#17a2b8'
    };
    notification.style.backgroundColor = colors[type] || colors.info;
    
    document.body.appendChild(notification);
    
    // Remove after 3 seconds
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => {
            if (notification.parentNode) {
                notification.parentNode.removeChild(notification);
            }
        }, 300);
    }, 3000);
}

function showError(message) {
    showNotification(message, 'error');
}

function showDialog(title, content, buttonText, onConfirm) {
    // Simple dialog implementation
    const dialog = document.createElement('div');
    dialog.className = 'dialog-overlay';
    dialog.innerHTML = `
        <div class="dialog">
            <div class="dialog-header">
                <h3>${title}</h3>
                <button class="dialog-close" onclick="this.closest('.dialog-overlay').remove()">×</button>
            </div>
            <div class="dialog-content">
                ${content}
            </div>
            <div class="dialog-actions">
                <button class="btn btn-secondary" onclick="this.closest('.dialog-overlay').remove()">Cancel</button>
                <button class="btn btn-primary" onclick="handleDialogConfirm()">${buttonText}</button>
            </div>
        </div>
    `;
    
    // Style the dialog
    Object.assign(dialog.style, {
        position: 'fixed',
        top: '0',
        left: '0',
        width: '100%',
        height: '100%',
        backgroundColor: 'rgba(0, 0, 0, 0.5)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: '10000'
    });
    
    // Store the confirm callback
    window.currentDialogConfirm = () => {
        if (onConfirm) onConfirm();
        dialog.remove();
    };
    
    document.body.appendChild(dialog);
}

function handleDialogConfirm() {
    if (window.currentDialogConfirm) {
        window.currentDialogConfirm();
    }
}

// Add CSS animations for notifications
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from { transform: translateX(100%); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
    }
    
    @keyframes slideOut {
        from { transform: translateX(0); opacity: 1; }
        to { transform: translateX(100%); opacity: 0; }
    }
    
    .dialog {
        background: white;
        border-radius: 12px;
        padding: 0;
        max-width: 500px;
        width: 90%;
        box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
    }
    
    .dialog-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 20px;
        border-bottom: 1px solid #f0f0f0;
    }
    
    .dialog-close {
        background: none;
        border: none;
        font-size: 24px;
        cursor: pointer;
        color: #999;
    }
    
    .dialog-content {
        padding: 20px;
    }
    
    .dialog-actions {
        display: flex;
        justify-content: flex-end;
        gap: 10px;
        padding: 20px;
        border-top: 1px solid #f0f0f0;
    }
    
    .form-group {
        margin-bottom: 15px;
    }
    
    .form-group label {
        display: block;
        margin-bottom: 5px;
        font-weight: 500;
    }
    
    .form-group input,
    .form-group select {
        width: 100%;
        padding: 8px 12px;
        border: 1px solid #ddd;
        border-radius: 6px;
        font-size: 14px;
    }
    
    .btn-sm {
        padding: 6px 12px;
        font-size: 12px;
    }
    
    .loading-message, .error-message, .empty-message {
        text-align: center;
        padding: 40px;
        color: #666;
        font-style: italic;
    }
    
    .health-summary {
        background: #f8f9fa;
        padding: 20px;
        border-radius: 8px;
        margin-bottom: 20px;
    }
    
    .health-stats {
        display: flex;
        gap: 30px;
        margin-top: 15px;
    }
    
    .stat {
        display: flex;
        flex-direction: column;
        align-items: center;
    }
    
    .stat-label {
        font-size: 14px;
        color: #666;
        margin-bottom: 5px;
    }
    
    .stat-value {
        font-size: 24px;
        font-weight: 600;
        color: #333;
    }
    
    .cluster-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 15px;
    }
    
    .cluster-details {
        margin-bottom: 15px;
    }
    
    .detail-item {
        display: flex;
        justify-content: space-between;
        margin-bottom: 8px;
    }
    
    .cluster-actions {
        display: flex;
        gap: 10px;
    }
    
    .deployment-status.running {
        color: #28a745;
        font-weight: 600;
    }
`;
document.head.appendChild(style);
