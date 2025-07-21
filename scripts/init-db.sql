-- PostgreSQL initialization script for Rancher Platform
CREATE DATABASE rancher_db;

-- Create tables
\c rancher_db;

CREATE TABLE IF NOT EXISTS clusters (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    status VARCHAR(50) DEFAULT 'active',
    node_count INTEGER DEFAULT 0,
    version VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS applications (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    cluster_id INTEGER REFERENCES clusters(id),
    namespace VARCHAR(255) DEFAULT 'default',
    status VARCHAR(50) DEFAULT 'running',
    image VARCHAR(255),
    replicas INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS deployments (
    id SERIAL PRIMARY KEY,
    application_id INTEGER REFERENCES applications(id),
    version VARCHAR(50),
    status VARCHAR(50) DEFAULT 'pending',
    deployed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO clusters (name, status, node_count, version) VALUES 
    ('development', 'active', 3, 'v1.28.4'),
    ('staging', 'active', 2, 'v1.28.4'),
    ('production', 'active', 5, 'v1.28.4')
ON CONFLICT (name) DO NOTHING;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_clusters_status ON clusters(status);
CREATE INDEX IF NOT EXISTS idx_applications_cluster_id ON applications(cluster_id);
CREATE INDEX IF NOT EXISTS idx_applications_status ON applications(status);
CREATE INDEX IF NOT EXISTS idx_deployments_application_id ON deployments(application_id);
